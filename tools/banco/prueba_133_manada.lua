-- Prueba de la 1.3.3, La Jauría y Lya (tools/prueba.py la corre con las demás):
--   1. la entrada en silencio: Lya guarda lo que diría, se presenta igual, y
--      al clic cuenta «¿Qué hay de nuevo? (N)» una cosa a la vez; pasada la
--      entrada, uno por latido;
--   2. «Te perdiste esto»: el aviso con botón que se fue sin tocarlo;
--   3. la guarida: «¿salimos del grupo?» mientras sigas en el grupo, 10 min;
--   4. la cita: «Armar el grupo» (tuya) y «Susurrar a X» (de otro);
--   5. raros con reloj: lo avisado sobrevive a un /reload;
--   6. una sola voz con Hoy (reparar, bolsas, entregar).
SNAPSHOTS = {}
-- 1.3.3: en el banco la entrada en silencio va apagada salvo que la escena la pida (Alfa_Nucleo/Entrada.lua).
BANCO_ENTRADA = true
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
local function check(cond, msg) if not cond then NOTE("1.3.3 manada", msg) end end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit
local N = AlfaNucleo
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
NOW = NOW + 120 -- pasada la entrada del arranque

local MN = NS_OF("Alfa_Manada")
local Ly = NS_OF("Alfa_Lya")
local R, U = MN.Red, MN.U
local Ce, UI = Ly.Cerebro, Ly.UI
local map = A.Compat.GetPlayerMapPosition()

local salidos, avisos = {}, {}
local function conRed(fn, sinCompartir)
  A.Set("manada.compartir", not sinCompartir)
  R.Escuchar()
  local via, envio, av, guild = R.Via, C_ChatInfo.SendAddonMessage, K.Aviso, IsInGuild
  R.Via = function() return "hermandad" end
  IsInGuild = function() return true end
  C_ChatInfo.SendAddonMessage = function(_, t, c, d) salidos[#salidos + 1] = { (t:gsub("|~[HA]$", "")), c, d } end
  K.Aviso = function(o) avisos[#avisos + 1] = o return true end
  local ok, e = pcall(fn)
  R.Via, C_ChatInfo.SendAddonMessage, K.Aviso, IsInGuild = via, envio, av, guild
  A.Set("manada.compartir", false)
  if not ok then error(e) end
end
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = t[k] } t[k] = v end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do t[k] = a.v end
  if not ok then error(e) end
end
local function vaciarCola() for _ = 1, 60 do FIRE(R.motor, "OnUpdate", 0.2) end end
local function llega(texto, quien, canal) FIRE_EVENT("CHAT_MSG_ADDON", "AlfaManada", texto .. "|~H", canal or "GUILD", quien) end

-- Lya a la vista y lo que dice (sin pintar el globo).
local dicho = {}
local function conLya(fn)
  con(UI, { Visible = function() return true end, Hablando = function() return false end,
    Hablar = function(c) dicho[#dicho + 1] = c end, Dormida = function() return false end }, fn)
end
local function latido()
  if not Ce.Latido then return false end
  Ce.Latido()
  return true
end

---------------------------------------------------------------------------
-- 1. La entrada en silencio
---------------------------------------------------------------------------

step("Al entrar Lya no habla sola: lo guarda y lo cuenta al clic", function()
  check(N.Entrando and N.GuardarAlEntrar and N.AlEntrar and N.EmpezarCuentaEntrada, "faltan las funciones de la entrada del núcleo")
  if not N.EmpezarCuentaEntrada then return end
  N.OlvidarAlEntrar()
  conLya(function()
    N.EmpezarCuentaEntrada()
    check(N.Entrando(), "no está en la entrada")
    dicho = {}
    local ok = Ce.Decir({ id = "llegada1", texto = "¡Te extrañé, Lobato!" })
    Ce.Decir({ id = "ayer", texto = "La última vez cazamos 3 raros.", acciones = { { texto = "Ver tu día", fn = function() end } } })
    check(ok == true and #dicho == 0, "al entrar Lya habló sola")
    local l = N.AlEntrar()
    check(#l == 2 and l[1].origen == "lya" and l[2].accion and l[2].accion.texto == "Ver tu día", "lo que diría no quedó guardado con su botón: " .. #l)
    -- Lo que pides y su presentación, sí.
    Ce.Decir({ id = "presentacion1", texto = "¡Hola! Soy Lya.", importante = true })
    check(#dicho == 1 and dicho[1].id == "presentacion1", "su presentación no salió al entrar")
    -- El clic: «¿Qué hay de nuevo? (2)».
    dicho = {}
    Ce.Pedir()
    local c = dicho[1]
    local b = c and c.acciones and c.acciones[1]
    check(b and b.texto == "¿Qué hay de nuevo? (2)", "el clic no ofreció «¿Qué hay de nuevo? (2)»: " .. tostring(b and b.texto))
    if b then b.fn() end
    local c2 = dicho[2]
    check(c2 and c2.texto == "¡Te extrañé, Lobato!", "no contó lo primero: " .. tostring(c2 and c2.texto))
    local sig = c2 and c2.acciones and c2.acciones[#c2.acciones]
    check(sig and sig.texto == "¿Qué hay de nuevo? (1)", "no ofreció lo siguiente (1)")
    if sig then sig.fn() end
    local c3 = dicho[3]
    check(c3 and c3.texto == "La última vez cazamos 3 raros." and c3.acciones and c3.acciones[1].texto == "Ver tu día", "lo segundo no salió con su botón")
    check(#N.AlEntrar() == 0, "lo contado sigue guardado")
    -- Pasada la entrada: lo que quedó, uno por latido, una vez.
    N.EmpezarCuentaEntrada()
    Ce.Decir({ id = "fiesta", texto = "Hoy hay fiesta." })
    Ce.Decir({ id = "nuevo", texto = "Hay algo nuevo en Alfa." })
    NOW = NOW + 61
    check(not N.Entrando(), "la entrada no terminó")
    dicho = {}
    check(latido(), "no hay latido de Lya")
    check(#dicho == 1 and dicho[1].texto == "Hoy hay fiesta.", "el latido no dijo lo guardado: " .. #dicho)
    latido()
    check(#dicho == 2 and dicho[2].texto == "Hay algo nuevo en Alfa." and #N.AlEntrar() == 0, "el segundo latido no dijo lo siguiente")
    latido()
    local repetido = false
    for _, x in ipairs(dicho) do if x.texto == "Hoy hay fiesta." and x ~= dicho[1] then repetido = true end end
    check(not repetido, "repitió lo guardado")
  end)
  N.OlvidarAlEntrar()
  NOW = NOW + 61
end)

---------------------------------------------------------------------------
-- 2. «Te perdiste esto»
---------------------------------------------------------------------------

step("«Te perdiste esto»: el aviso con botón que se fue sin tocarlo", function()
  -- 1.3.7: la lista vive en el núcleo (N.Perdido, los últimos 30 por personaje): Ce.Perdidos().
  check(Ce.Perdido and Ce.Perdidos, "falta Ce.Perdido")
  if not Ce.Perdido then return end
  local n0 = #Ce.Perdidos()
  local tocado = false
  A.Fire("ALFA_AVISO_PERDIDO", { titulo = "Ana te abre la puerta", texto = "Acepta su invitación.", accion = { texto = "Aceptar", alClic = function() tocado = true end } })
  A.Fire("ALFA_AVISO_PERDIDO", { titulo = "Sin botón", texto = "Nada que hacer." })
  check(#Ce.Perdidos() == n0 + 1 and Ce.Perdidos()[1].titulo == "Ana te abre la puerta", "no guardó el aviso con botón (o guardó el que no tiene)")
  local x = Ce.Perdidos()[1]
  local ac = x and Ce.AccionPerdido(x)
  if ac then ac.fn() end
  check(tocado, "su botón no hace lo de antes")
  Ly.Guia.Abrir()
  RUN_TIMERS(2)
  Ce.OlvidarPerdido(x)
  check(#Ce.Perdidos() == n0, "no se olvidó al usarlo")
end)

---------------------------------------------------------------------------
-- 3. La guarida: ¿salimos del grupo?
---------------------------------------------------------------------------

step("Ya en la guarida y en el grupo: «¿salimos del grupo?» hasta 10 min", function()
  local Gu = MN.Guaridas
  check(Gu.RecordarSalir and Gu.Recordando, "falta el recordatorio de la guarida")
  if not Gu.RecordarSalir then return end
  local grupo = false
  conRed(function()
    con(_G, { IsInGroup = function() return grupo end, InviteUnit = function() end }, function()
      Gu.Ver(7001) Gu.Ver(7001)
      llega(("1G|%d|7002|1"):format(map), "Ana Smith")
      check(Gu.Pedir(7002), "no pidió entrar a la guarida de Ana")
      llega("1R|ok", "Ana Smith", "WHISPER")
      grupo = true
      Gu.Ver(7002) Gu.Ver(7002)
      check(Gu.Recordando(), "al llegar no empezó a recordar que salgas del grupo")
      avisos = {}
      Gu.RecordarSalir()
      local a = avisos[1]
      check(a and a.titulo:find("¿salimos del grupo?", 1, true) and a.accion and a.accion.texto == "Salir del grupo", "no recordó «¿salimos del grupo?»")
      -- Saliste: se acaba.
      grupo = false
      avisos = {}
      Gu.RecordarSalir()
      check(#avisos == 0 and not Gu.Recordando(), "fuera del grupo siguió recordando")
    end)
  end)
end)

---------------------------------------------------------------------------
-- 4. La cita: armar el grupo, susurrar
---------------------------------------------------------------------------

step("La cita: «Armar el grupo» si es tuya, «Susurrar a X» si es de otro", function()
  local Ci = MN.Cita
  check(Ci.Accion and Ci.ArmarGrupo, "faltan Ci.Accion o Ci.ArmarGrupo")
  if not Ci.Accion then return end
  local reloj = GetServerTime()
  local invitados = {}
  conRed(function()
    con(C_PartyInfo or {}, { InviteUnit = function(n) invitados[#invitados + 1] = n end }, function()
      for _, c in ipairs(Ci.Lista()) do Ci.Quitar(c.llave) end
      check(Ci.Proponer("Minas de la Muerte", reloj + 600), "no propuso la cita")
      local mia
      for _, c in ipairs(Ci.Lista()) do if c.mia then mia = c end end
      check(mia and Ci.Accion(mia) == nil, "sin nadie que vaya ofreció armar el grupo")
      llega(("1D|%d|s"):format(mia and mia.id or 0), "Beto Ruiz", "WHISPER")
      local a = Ci.Accion(mia)
      check(a and a.texto == "Armar el grupo", "con Beto que va, no ofreció «Armar el grupo»")
      if a then a.alClic() end
      check(invitados[1] == "Beto Ruiz", "«Armar el grupo» no invitó a Beto: " .. tostring(invitados[1]))
      -- El recordatorio trae el botón.
      avisos = {}
      mia.recordada = nil
      Ci.Recordar()
      local r
      for _, x in ipairs(avisos) do if x.titulo == "Tu cita con la manada" then r = x end end
      check(r and r.accion and r.accion.texto == "Armar el grupo", "el aviso de 15 min no trae «Armar el grupo»")
      -- La de otro: «Susurrar a Elsa Mora».
      llega(("1C|41|%d|Vallefresno"):format(reloj + 3600), "Elsa Mora")
      local suya
      for _, c in ipairs(Ci.Lista()) do if c.que == "Vallefresno" then suya = c end end
      local s = suya and Ci.Accion(suya)
      check(s and s.texto == "Susurrar a Elsa Mora", "la cita de otro no ofrece «Susurrar a Elsa Mora»: " .. tostring(s and s.texto))
      for _, c in ipairs(Ci.Lista()) do Ci.Quitar(c.llave) end
    end)
  end)
end)

---------------------------------------------------------------------------
-- 5. Raros con reloj: lo avisado sobrevive a un /reload
---------------------------------------------------------------------------

step("«Pudo volver ya» no se repite tras un /reload", function()
  local Rl = MN.Reloj
  Rl.Olvidar()
  conRed(function()
    A.Set("manada.rarosManada", true)
    llega(("1T|%d|50.00|50.00|1900|Gorlash"):format(map), "Ana Smith")
    avisos = {}
    check(Rl.Revisar() == 1, "no avisó que pudo volver")
    local d = N.DatosPersonaje("manada")
    local guardado = type(d.rarosAvisados) == "table" and next(d.rarosAvisados) ~= nil
    check(guardado, "lo avisado no quedó guardado por personaje")
    check(Rl.Revisar() == 0, "avisó dos veces")
  end)
  Rl.Olvidar()
end)

---------------------------------------------------------------------------
-- 6. Una sola voz con Hoy
---------------------------------------------------------------------------

step("Reparar: si Hoy ya lo dijo en la sesión, Lya no lo repite", function()
  check(Ce.YaSeDijo and Ce.Anotar, "faltan Ce.YaSeDijo o Ce.Anotar")
  if not Ce.YaSeDijo then return end
  N.dichosSesion = N.dichosSesion or {}
  con(_G, { GetInventoryItemDurability = function() return 10, 100 end }, function()
    conLya(function()
      N.dichosSesion.reparar = GetTime()
      dicho = {}
      NOW = NOW + 600
      latido()
      local dijo = false
      for _, c in ipairs(dicho) do if tostring(c.id):find("^reparar") then dijo = true end end
      check(not dijo, "Lya repitió «reparar» después de Hoy")
      N.dichosSesion.reparar = nil
      dicho = {}
      NOW = NOW + 600
      latido()
      dijo = false
      for _, c in ipairs(dicho) do if tostring(c.id):find("^reparar") then dijo = true end end
      check(dijo, "sin Hoy, Lya no dijo «reparar»")
      check(N.dichosSesion.reparar ~= nil, "al decirlo no lo anotó para Hoy")
    end)
  end)
end)

print(string.format("PRUEBA: 1.3.3 La Jauría y Lya, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
