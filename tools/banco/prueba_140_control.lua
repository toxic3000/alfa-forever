-- Prueba de la 1.4.0 (control): los bugs de Toxic con la 1.4.0 instalada.
--   1. «Cuando habla Lya se congela la pantalla y no puedo mover la cámara»:
--      cada frase de Lya, de punta a punta, cuesta poco (50 frases, tope por
--      frase) y no carga ningún paquete; su globo no se queda con el clic (el
--      clic y el arrastre de la cámara que empiezan sobre él llegan al mundo);
--      en combate Lya tampoco atrapa clics; el globo no se queda para siempre
--      con el ratón quieto encima.
--   2. «No puedo cambiar el audio»: con todos los módulos cargados, lo que el
--      jugador cambia en Opciones > Audio (y Ctrl+S, los atajos de volumen) se
--      queda: ningún módulo vuelve a escribir una variable de sonido después,
--      pase lo que pase (relojes, combate, cambiar de zona, ajustes, entrar).
--   3. Clics y cámara: ningún marco de Alfa atrapa clics del mundo sin verse;
--      WorldFrame queda en su lugar; Alfa gasta poco tiempo por cuadro.
--   4. /alfa sonido también devuelve la interacción y la cámara que dejó la
--      pesca (SoftTarget*), sin tocar lo que el jugador eligió.
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
local function check(cond, msg) if not cond then NOTE("1.4.0 control", msg) end end
local function T(n) RUN_TIMERS(n or 3) end
local clock = os.clock

-- Las variables del juego, con su valor de fábrica, como el juego: escribir
-- avisa con CVAR_UPDATE en el momento (síncrono). Se anota quién escribe.
local FABRICA = {
  Sound_EnableAllSound = "1", Sound_MasterVolume = "1", Sound_EnableMusic = "1", Sound_MusicVolume = "0.4",
  Sound_EnableAmbience = "1", Sound_AmbienceVolume = "0.6", Sound_EnableSFX = "1", Sound_SFXVolume = "1",
  Sound_EnableDialog = "1", Sound_DialogVolume = "1", Sound_EnablePetSounds = "1", Sound_EnableEmoteSounds = "1",
  Sound_EnableErrorSpeech = "1", Sound_EnableSoundWhenGameIsInBG = "0",
  SoftTargetInteract = "1", SoftTargetInteractArc = "0", SoftTargetInteractRange = "10", SoftTargetIconGameObject = "0",
  SoftTargetIconInteract = "1",
  cameraSmoothStyle = "4", cameraPivot = "1", cameraIndirectVisibility = "0", cameraTerrainTilt = "0",
  cameraDistanceMaxZoomFactor = "1.9", instantQuestText = "0", autoLootDefault = "0",
}
local cv = {}
local escritas = {}
local tocadas
local function reiniciar() cv, escritas, tocadas = {}, {}, {} for k, v in pairs(FABRICA) do cv[k] = v end end
reiniciar()
local function leer(n) local v = cv[n] if v == nil then return "0" end return v end
local function alfaEscribe(n, v)
  v = v ~= nil and tostring(v) or nil
  cv[n] = v
  escritas[#escritas + 1] = { n = n, v = v, quien = debug.traceback("", 3):sub(1, 400) }
  FIRE_EVENT("CVAR_UPDATE", n, v)
  return true
end
C_CVar.GetCVar = function(n) return leer(n) end
C_CVar.SetCVar = alfaEscribe
C_CVar.GetCVarDefault = function(n) return FABRICA[n] end
GetCVar = function(n) return leer(n) end
SetCVar = alfaEscribe
-- El jugador (el menú de Audio, Ctrl+S, la tecla de volumen): no cuenta como de Alfa.
local function jugador(n, v)
  tocadas[n] = true
  cv[n] = v
  FIRE_EVENT("CVAR_UPDATE", n, v)
end
-- Lo que el jugador cambió y Alfa volvió a escribir después (desde: el
-- índice de escritas antes de los cambios del jugador). todo: cualquier
-- variable de sonido (sin pesca, Alfa no tiene por qué escribir ninguna).
local function sonidoEscrito(desde, todo)
  for i = desde + 1, #escritas do
    local e = escritas[i]
    if e.n:find("^Sound_") and (todo or tocadas[e.n]) then return e end
  end
end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
print("errores al entrar:", #ERRORS)

local Ly = NS_OF("Alfa_Lya")
local P = NS_OF("Alfa_Pesca")
local Ce, UI = Ly and Ly.Cerebro, Ly and Ly.UI

---------------------------------------------------------------------------
-- 1. Lya: hablar no pesa
---------------------------------------------------------------------------
local cargas = {}
do
  local viejo = LoadAddOn
  LoadAddOn = function(n, ...) cargas[#cargas + 1] = tostring(n) return viejo(n, ...) end
  if C_AddOns and C_AddOns.LoadAddOn then
    local v2 = C_AddOns.LoadAddOn
    C_AddOns.LoadAddOn = function(n, ...) cargas[#cargas + 1] = tostring(n) return v2(n, ...) end
  end
end

step("Lya: 50 frases cuestan poco y no cargan nada", function()
  check(Ce and UI and Ce.Decir and UI.Hablar, "faltan Cerebro/UI de Lya")
  if not (Ce and UI) then return end
  -- El banco empieza con la bienvenida pendiente: Lya, a la vista.
  local B = rawget(_G, "AlfaBienvenida")
  if type(B) == "table" then B.Pendiente = function() return false end end
  if UI.Aplicar then UI.Aplicar() end
  T(5)
  check(UI.Visible(), "Lya no está a la vista en el banco")
  -- Unas misiones abiertas con texto largo (lo que Lya lee para «el lore de tus misiones»).
  local H = Ly.Historias
  local q = H and H.Todas and H.Todas()
  if type(q) == "table" then
    local largo = string.rep("Los Defias atacan la granja; los múrlocs de la costa y los gnolls del bosque. ", 12)
    local ahora = GetServerTime and GetServerTime() or 0
    for i = 1, 40 do q[90000 + i] = { t = "Misión " .. i, d = largo, o = largo, a = ahora - 3600, u = ahora } end
  end
  local antes = #cargas
  local fuentes = {
    function(i) return Ce.Decir({ texto = "Frase pedida " .. i .. ": algo de lo que Lya platica, con dos o tres líneas en su globo.", pedido = true }) end,
    function() return Ly.Charla and Ly.Charla.Pedido and Ly.Charla.Pedido() end,
    function() return Ce.Pedir and Ce.Pedir() end,
    function() return Ly.LoreMisiones and Ly.LoreMisiones.Algo({ pedido = true }) end,
    function() return Ly.Recuerdos and Ly.Recuerdos.Algo({ pedido = true }) end,
    function() Ce.EmpezoSesion(-99999) return Ce.Latido and Ce.Latido() end,
  }
  local peor, total, n, cual = 0, 0, 0, nil
  for i = 1, 50 do
    UI.Callar(true)
    local t0 = clock()
    local ok, e = pcall(fuentes[(i - 1) % #fuentes + 1], i)
    local dt = clock() - t0
    if not ok then NOTE("Lya habla", e) end
    total, n = total + dt, n + 1
    if dt > peor then peor, cual = dt, (i - 1) % #fuentes + 1 end
  end
  local media = total / n * 1000
  print(("  Lya: %d frases, media %.2f ms, peor %.2f ms (fuente %s)"):format(n, media, peor * 1000, tostring(cual)))
  check(media < 2, ("cada frase de Lya tarda %.2f ms en promedio (tope 2 ms)"):format(media))
  check(peor * 1000 < 16, ("una frase de Lya tardó %.2f ms (más de un cuadro)"):format(peor * 1000))
  check(#cargas == antes, "Lya cargó paquetes al hablar: " .. table.concat(cargas, ", ", antes + 1))
  -- El lore de tus misiones: el tema de cada misión se calcula una vez.
  if Ly.LoreMisiones then
    -- Las nuevas se calculan de a poco (unas pocas por latido); ya vistas, no.
    for _ = 1, 40 do Ly.LoreMisiones.Temas() end
    local t0 = clock()
    for _ = 1, 20 do Ly.LoreMisiones.Temas() end
    local dt = (clock() - t0) / 20 * 1000
    print(("  LoreMisiones.Temas con 40 misiones abiertas: %.2f ms"):format(dt))
    check(dt < 1, ("LoreMisiones.Temas sigue leyendo todas las misiones en cada latido (%.2f ms)"):format(dt))
  end
  if type(q) == "table" then for i = 1, 40 do q[90000 + i] = nil end end
end)

step("Lya: su globo no atrapa el clic ni el arrastre de la cámara", function()
  if not (Ce and UI) then return end
  UI.Callar(true)
  Ce.Decir({ texto = "Una frase con un botón.", pedido = true, acciones = { { texto = "Ver", fn = function() end } } })
  local g = rawget(_G, "AlfaLyaGlobo")
  check(g and g:IsShown(), "el globo de Lya no salió")
  if not g then return end
  check(g:IsMouseClickEnabled() == false, "el globo de Lya se queda con el clic (el clic al bicho o la cámara no llegan)")
  check(g:IsMouseMotionEnabled() == true, "el globo de Lya ya no muestra el texto completo al pasar el ratón")
  check(g.B1 and g.B1:IsMouseEnabled() ~= false, "el botón del globo ya no se clica")
  check(g.Cerrar and g.Cerrar:IsMouseEnabled() ~= false, "la X del globo ya no se clica")
  -- En combate Lya no atrapa clics (antes solo en modo foco).
  local f = rawget(_G, "AlfaLyaLoba")
  UI.Combate(true)
  check(f and f:IsMouseEnabled() == false, "en combate Lya atrapa clics")
  UI.Combate(false)
  check(f and f:IsMouseEnabled() ~= false, "al salir del combate Lya ya no se clica")
  -- Con el ratón quieto encima, el globo se va de todos modos.
  local sobre = g.IsMouseOver
  g.IsMouseOver = function() return true end
  T(30)
  check(not g:IsShown() or not UI.Hablando(), "con el ratón quieto encima el globo se queda para siempre")
  g.IsMouseOver = sobre
  UI.Callar(true)
end)

---------------------------------------------------------------------------
-- 2. El audio: lo que cambias tú se queda
---------------------------------------------------------------------------
local AUDIO = {
  { "Sound_MasterVolume", "0.25" }, { "Sound_EnableAllSound", "0" }, { "Sound_EnableAllSound", "1" },
  { "Sound_MusicVolume", "0.9" }, { "Sound_SFXVolume", "0.3" }, { "Sound_AmbienceVolume", "0.1" },
  -- Ctrl+S (Sound_ToggleSound de Blizzard_SharedXML/Mainline/Sound.lua)
  { "Sound_EnableSFX", "0" }, { "Sound_EnableAmbience", "0" }, { "Sound_EnableDialog", "0" },
  { "Sound_EnableMusic", "0" }, { "Sound_EnablePetSounds", "0" }, { "Sound_EnableErrorSpeech", "0" },
}
local function sacudir()
  -- Lo que pasa jugando: relojes, combate, zona, ajustes, entrar otra vez.
  T(20)
  FIRE_EVENT("PLAYER_REGEN_DISABLED") T(2) FIRE_EVENT("PLAYER_REGEN_ENABLED") T(3)
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA") FIRE_EVENT("ZONE_CHANGED") T(3)
  if Alfa and Alfa.Fire then Alfa.Fire("SETTING_CHANGED", "") end
  T(3)
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false) T(10)
  FIRE_EVENT("UPDATE_BINDINGS") T(2)
end

step("Audio: lo que cambias tú se queda (todos los módulos)", function()
  reiniciar()
  T(5)
  local desde = #escritas
  for _, c in ipairs(AUDIO) do jugador(c[1], c[2]) end
  sacudir()
  local e = sonidoEscrito(desde, true)
  check(e == nil, e and ("Alfa volvió a escribir " .. e.n .. "=" .. tostring(e.v) .. " después de que lo cambiaste:" .. e.quien) or "")
  local final = {}
  for _, c in ipairs(AUDIO) do final[c[1]] = c[2] end
  for n, v in pairs(final) do check(cv[n] == v, n .. " no se quedó como lo pusiste (" .. tostring(cv[n]) .. ")") end
end)

step("Audio: con la pesca abierta, lo tuyo también manda", function()
  if not (P and P.AbrirModo) then return end
  reiniciar()
  local Eq = P.Eq
  local cana = Eq and Eq.CanaPuesta
  if Eq then Eq.CanaPuesta = function() return true end end
  Alfa.Set("pesca.activo", true)
  Alfa.Set("pesca.sonido", true)
  P.AbrirModo(true)
  local desde = #escritas
  for _, c in ipairs(AUDIO) do jugador(c[1], c[2]) end
  P.Aplicar() P.Reaplicar()
  sacudir()
  P.CerrarModo(true, true)
  T(5)
  local e = sonidoEscrito(desde)
  check(e == nil, e and ("con la pesca, Alfa pisó " .. e.n .. "=" .. tostring(e.v) .. ":" .. e.quien) or "")
  if Eq then Eq.CanaPuesta = cana end
end)

step("Audio: con «Silenciar diálogos» de Comodidades, prenderlos tú manda", function()
  reiniciar()
  Alfa.Set("comodidades.silenciarDialogos", true)
  T(3)
  check(cv.Sound_EnableDialog == "0", "Comodidades no calló los diálogos")
  local desde = #escritas
  jugador("Sound_EnableDialog", "1")
  sacudir()
  local e = sonidoEscrito(desde)
  check(e == nil, e and ("Comodidades volvió a callar " .. e.n .. ":" .. e.quien) or "")
  check(cv.Sound_EnableDialog == "1", "los diálogos que prendiste se volvieron a callar")
  check(Alfa.Get("comodidades.silenciarDialogos") ~= true, "la opción de Comodidades siguió prendida")
  Alfa.Set("comodidades.silenciarDialogos", false)
end)

---------------------------------------------------------------------------
-- 3. Clics y cámara
---------------------------------------------------------------------------
local function alfaEfectiva(f)
  local a, x = 1, f
  while x do a = a * (rawget(x, "_alpha") or 1) x = rawget(x, "_parent") end
  return a
end
local function nombreDe(f)
  local partes, x = {}, f
  for _ = 1, 5 do
    if not x then break end
    local n = x.GetName and x:GetName()
    partes[#partes + 1] = (type(n) == "string" and n) or ("<" .. tostring(rawget(x, "_kind")) .. ">")
    x = rawget(x, "_parent")
  end
  return table.concat(partes, " < ")
end
-- ¿Tiene algo que se vea? (una textura o un texto a la vista con alfa)
local function seVe(f, prof)
  prof = prof or 0
  if tostring(rawget(f, "_text") or "") ~= "" then return true end
  if prof > 4 then return false end
  for _, c in ipairs(rawget(f, "_children") or {}) do
    if rawget(c, "_shown") and (rawget(c, "_alpha") or 1) > 0.02 then
      local k = rawget(c, "_kind")
      if k == "Texture" and (rawget(c, "_tex") or rawget(c, "_color") or rawget(c, "_atlas") or true) then return true end
      if k == "FontString" and tostring(rawget(c, "_text") or "") ~= "" then return true end
      if k ~= "Texture" and k ~= "FontString" and seVe(c, prof + 1) then return true end
    end
  end
  return false
end

-- Una zona de clic transparente sobre un panel que sí se ve (la cabecera del
-- rastreador, por ejemplo) no tapa el mundo: el panel ya está ahí.
local function dentroDeAlgoVisible(f)
  local l, b, w, h = f:GetRect()
  local x = rawget(f, "_parent")
  for _ = 1, 6 do
    if not x or x == UIParent then return false end
    local n = x.GetName and x:GetName()
    if n == "AlfaUIParent" then return false end
    if x:IsVisible() and alfaEfectiva(x) > 0.05 and seVe(x) then
      local pl, pb, pw, ph = x:GetRect()
      if l >= pl - 1 and b >= pb - 1 and l + w <= pl + pw + 1 and b + h <= pb + ph + 1 then return true end
    end
    x = rawget(x, "_parent")
  end
  return false
end

step("Clics: ningún marco de Alfa atrapa clics sin verse", function()
  -- La intro del lobo termina sola (el banco no avanza GetTime): se cierra a mano.
  local intro = rawget(_G, "AlfaIntro")
  if intro and intro:IsShown() then intro:Hide() end
  T(10)
  local malos = {}
  for _, f in ipairs(ALL_FRAMES()) do
    local k = rawget(f, "_kind")
    if k ~= "Texture" and k ~= "FontString" and f:IsVisible() and rawget(f, "_mouse") and rawget(f, "_clic") ~= false then
      local w, h = f:GetWidth(), f:GetHeight()
      local nombre = nombreDe(f)
      if w * h > 0 and nombre:find("Alfa", 1, true) and not nombre:find("Minimap", 1, true) then
        local a = alfaEfectiva(f)
        if a < 0.05 or (not seVe(f) and not dentroDeAlgoVisible(f)) then malos[#malos + 1] = ("%s (%dx%d, alfa %.2f)"):format(nombre, w, h, a) end
      end
    end
  end
  check(#malos == 0, "marcos invisibles que atrapan clics: " .. table.concat(malos, "; "))
end)

step("Clics: WorldFrame queda en toda la pantalla", function()
  local W = rawget(_G, "WorldFrame")
  if not (W and W.GetRect) then return end
  local l, b, w, h = W:GetRect()
  local U = UIParent
  local ul, ub, uw, uh = U:GetRect()
  check(math.abs((l or 0) - (ul or 0)) < 1 and math.abs((b or 0) - (ub or 0)) < 1 and math.abs((w or 0) - (uw or 0)) < 1 and math.abs((h or 0) - (uh or 0)) < 1,
    ("WorldFrame quedó corrido: %s,%s %sx%s"):format(tostring(l), tostring(b), tostring(w), tostring(h)))
  check((W:GetScale() or 1) == 1, "WorldFrame quedó escalado")
end)

step("Rendimiento: el tiempo de Alfa por cuadro", function()
  local marcos = {}
  for _, f in ipairs(ALL_FRAMES()) do
    local s = rawget(f, "_scripts")
    if s and s.OnUpdate and f:IsVisible() then marcos[#marcos + 1] = f end
  end
  local N_CUADROS = 300
  local t0 = clock()
  for _ = 1, N_CUADROS do
    for _, f in ipairs(marcos) do
      local fn = rawget(f, "_scripts").OnUpdate
      if fn then pcall(fn, f, 1 / 60) end
    end
  end
  local cuadro = (clock() - t0) / N_CUADROS * 1000
  print(("  Alfa por cuadro: %.3f ms (%d OnUpdate vivos)"):format(cuadro, #marcos))
  check(cuadro < 1, ("Alfa gasta %.3f ms por cuadro en el banco (tope 1 ms)"):format(cuadro))
end)

---------------------------------------------------------------------------
-- 4. /alfa sonido devuelve la interacción de la pesca
---------------------------------------------------------------------------
step("/alfa sonido: la interacción que dejó la pesca vuelve, lo tuyo no", function()
  if not (P and P.DevolverSonido) then return end
  reiniciar()
  -- Lo que deja la pesca (SoftTargetInteract 3, arco 2, 60 m) sin respaldo
  -- (un cierre de golpe de versiones viejas), y una cámara que elegiste tú.
  cv.SoftTargetInteract, cv.SoftTargetInteractArc, cv.SoftTargetInteractRange = "3", "2", "60"
  cv.cameraSmoothStyle = "0"
  AlfaNucleo.Datos("pesca").respaldo = nil
  AlfaNucleo.DatosPersonaje("pesca").respaldo = nil
  local cambio = P.DevolverSonido()
  check(type(cambio) == "table", "DevolverSonido no dio la lista")
  check(cv.SoftTargetInteract == "1" and cv.SoftTargetInteractArc == "0" and cv.SoftTargetInteractRange == "10",
    ("la interacción de la pesca no volvió: %s/%s/%s"):format(cv.SoftTargetInteract, cv.SoftTargetInteractArc, cv.SoftTargetInteractRange))
  check(cv.cameraSmoothStyle == "0", "/alfa sonido cambió una cámara que no era de Alfa")
  -- Lo que el jugador tiene distinto de la pesca no se toca.
  reiniciar()
  cv.SoftTargetInteract = "2"
  P.DevolverSonido()
  check(cv.SoftTargetInteract == "2", "/alfa sonido cambió tu interacción suave (no era de la pesca)")
  -- Pescando, no.
  reiniciar()
end)

print("pasos:", pasos, "errores:", #ERRORS)
