-- Prueba de la 1.4.0, cacería de bugs (83 y 85; tools/prueba.py la corre):
--   * «Tus conjuntos · Pesca» (Bolsas/Cambio.lua) salía arriba a la derecha de
--     la ventana de tu personaje, encima de la columna de pestañas de Forever
--     (personaje, reputación, habilidades...). Ahora viene apagado (y la
--     migración 5 lo apaga a quien lo tenía); prendido, sale después de las
--     pestañas, o debajo si no cabe; se mueve con «Acomodar la pantalla».
--   * Lya: la tarjeta de los consejos («Consejos: …» cortado).
--   * Lobos con Alfa sin hermandad: sin la sección vacía ni «1.4.0: 1».
--   * Dos pantallas con la interfaz grande (768 de alto): cabe en la pantalla.
--   * Paisaje y gráficos: «Lo marcado con ★ también está en el menú del juego».
--   * Estrellas guía: el número de cada fila sin ancho fijo (no sale «…»).
SNAPSHOTS = {}
BANCO_LETRA = 0.64
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["140-bugs-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.4.0 bugs", msg) end end
local function T(n) RUN_TIMERS(n or 3) end

-- El equipo de mentira: una espada puesta y un conjunto «Pesca» con la caña.
local OBJ = {
  [9201] = { "Espada del lobo", 2, "INVTYPE_WEAPON" },
  [6256] = { "Caña de pescar", 1, "INVTYPE_2HWEAPON" },
  [9103] = { "Gorro", 1, "INVTYPE_HEAD" },
  [9104] = { "Sombrero de pesca", 2, "INVTYPE_HEAD" },
}
local function enlace(id) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. OBJ[id][1] .. "]|h|r" end
local function idDe(x) return tonumber(x) or tonumber(tostring(x):match("item:(%d+)")) end
C_Item.GetItemInfo = function(x)
  local id = idDe(x)
  local o = id and OBJ[id]
  if not o then return nil end
  return o[1], enlace(id), o[2], 20, 1, "Tipo", "Subtipo", 1, o[3], 134400, 1, 2, 7
end
GetItemInfo = C_Item.GetItemInfo
C_Item.GetItemInfoInstant = function(x)
  local id = idDe(x)
  local o = id and OBJ[id]
  if not o then return nil end
  return id, "Tipo", "Subtipo", o[3], 134400, 2, 7
end
local puesto = { [16] = enlace(9201), [1] = enlace(9103) }
GetInventoryItemLink = function(_, r) return puesto[r] end
GetInventoryItemID = function(_, r) local l = puesto[r] return l and idDe(l) end

-- La ventana de tu personaje de Forever: 384 x 512, 30 px transparentes a la
-- derecha y una columna de 6 pestañas afuera, pegada a su borde que se ve.
local fondo = CreateFrame("Frame", nil, UIParent)
fondo:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
fondo:SetSize(760, 660)
local ft = fondo:CreateTexture(nil, "BACKGROUND")
ft:SetAllPoints(fondo)
ft:SetColorTexture(0.05, 0.07, 0.1, 1)
fondo:Hide()
local cf = rawget(_G, "CharacterFrame") or CreateFrame("Frame", "CharacterFrame", UIParent)
cf:SetSize(384, 512)
cf:ClearAllPoints()
cf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
rawset(cf, "GetHitRectInsets", function() return 0, 30, 0, 75 end)
local arte = cf:CreateTexture(nil, "BACKGROUND")
arte:SetPoint("TOPLEFT", cf, "TOPLEFT", 10, -12)
arte:SetSize(344, 425)
arte:SetColorTexture(0.32, 0.27, 0.2, 1)
local pestanas = {}
for i = 1, 6 do
  local p = CreateFrame("Button", nil, cf)
  p:SetSize(46, 46)
  p:SetPoint("TOPLEFT", cf, "TOPRIGHT", -30 + 2, -20 - (i - 1) * 52)
  local t = p:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints(p)
  t:SetColorTexture(0.55, 0.42, 0.18, 1)
  pestanas[i] = p
end
cf:Hide()

Alfa.Hidden = Alfa.Hidden or function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
FIRE_EVENT("PLAYER_LOGIN")
do
  local Bv = rawget(_G, "AlfaBienvenida")
  AlfaNucleo.Datos("bienvenida").respondio = Bv and Bv.VERSION or 99
  AlfaNucleo.Datos("bienvenida").versionVista = Bv and Bv.VersionAlfa and Bv.VersionAlfa() or "9.9.9"
  AlfaNucleo.Datos("bienvenida").recorrido = true
end
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(8)
if Alfa.UI and Alfa.UI.Options and Alfa.UI.Options.frame then Alfa.UI.Options.frame:Hide() end

local N, K = AlfaNucleo, AlfaNucleo.Kit
local B = NS_OF("Alfa_Bolsas")
local Cb, Cj = B.Cambio, B.Conjuntos

local function encima(a, b)
  local al, ab, aw, ah = a:GetRect()
  local bl, bb, bw, bh = b:GetRect()
  return al < bl + bw and bl < al + aw and ab < bb + bh and bb < ab + ah
end

step("Conjuntos: apagado de fábrica, no sale con tu ventana", function()
  check(Alfa.Get("bolsas.barraConjuntos") == false, "bolsas.barraConjuntos no viene apagado: " .. tostring(Alfa.Get("bolsas.barraConjuntos")))
  puesto[16], puesto[1] = enlace(6256), enlace(9104)
  Cj.Guardar("Pesca")
  puesto[16], puesto[1] = enlace(9201), enlace(9103)
  cf:Show()
  T(2)
  local barra = Cb.Barra()
  check(not (barra and barra:IsShown()), "el panel «Tus conjuntos» salió solo con tu ventana")
  cf:Hide()
  T(1)
end)

step("Conjuntos: la migración 5 lo apaga a quien lo tenía", function()
  check(type(Cb.Migracion140) == "function", "falta Cb.Migracion140")
  local db = { settings = { bolsas = { barraConjuntos = true, conjuntos = true } } }
  Cb.Migracion140(db)
  check(db.settings.bolsas.barraConjuntos == nil, "la migración no lo apagó")
  check(db.settings.bolsas.conjuntos == true, "la migración tocó otro ajuste")
  Cb.Migracion140({})
  Cb.Migracion140({ settings = {} })
end)

step("Conjuntos: prendido, sale después de las pestañas de Forever", function()
  Alfa.Set("bolsas.barraConjuntos", true)
  fondo:Show()
  cf:Show()
  T(2)
  local barra = Cb.Barra()
  check(barra and barra:IsShown(), "prendido, el panel no salió")
  if not barra then return end
  for i, p in ipairs(pestanas) do
    check(not encima(barra, p), ("el panel se encima con la pestaña %d (panel %s, pestaña %s)"):format(i, tostring(barra:GetLeft()), tostring(p:GetLeft())))
  end
  check(barra:GetLeft() >= pestanas[1]:GetRight() + 4, "el panel no deja aire después de las pestañas")
  check(barra:GetRight() <= UIParent:GetWidth(), "el panel se sale de la pantalla")
  SNAP("conjuntos-pestanas", fondo, { cf, barra })
  -- Nada de Alfa visible se encima con las pestañas.
  for _, f in ipairs(UIParent._children) do
    local n = f.GetName and f:GetName()
    if type(n) == "string" and n:find("^Alfa") and f:IsVisible() and n ~= "AlfaUIParent" and n ~= "AlfaIntro" then
      for i, p in ipairs(pestanas) do
        if encima(f, p) and (f:GetEffectiveAlpha() or 1) > 0.05 then NOTE("1.4.0 bugs", n .. " se encima con la pestaña " .. i) end
      end
    end
  end
  cf:Hide()
  T(1)
  check(not barra:IsShown(), "con tu ventana cerrada el panel sigue")
end)

step("Conjuntos: sin lugar a la derecha, debajo de tu ventana", function()
  cf:ClearAllPoints()
  cf:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -116)
  cf:Show()
  T(2)
  local barra = Cb.Barra()
  check(barra and barra:IsShown(), "el panel no salió")
  if not barra then return end
  check(barra:GetRight() <= UIParent:GetWidth() + 1 and barra:GetLeft() >= 0, "el panel se salió de la pantalla")
  check(barra:GetTop() <= cf:GetBottom() + 75 + 1, "sin lugar a la derecha, el panel no bajó")
  for i, p in ipairs(pestanas) do check(not encima(barra, p), "debajo, el panel se encima con la pestaña " .. i) end
  cf:Hide()
  cf:ClearAllPoints()
  cf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
  T(1)
end)

step("Conjuntos: se acomoda arrastrando y vuelve a su lugar", function()
  check(K.MovibleDe and K.MovibleDe("bolsas.conjuntos"), "el panel no está en «Acomodar la pantalla»")
  if not (K.MovibleDe and K.MovibleDe("bolsas.conjuntos")) then return end
  cf:Show()
  T(2)
  local barra = Cb.Barra()
  K.MovibleSoltar("bolsas.conjuntos", 900, 500, barra:GetWidth(), barra:GetHeight())
  local l0, b0 = barra:GetLeft(), barra:GetBottom() -- (el imán lo acomoda unos píxeles)
  cf:Hide() T(1) cf:Show() T(2)
  check(math.abs((barra:GetLeft() or 0) - l0) <= 1 and math.abs((barra:GetBottom() or 0) - b0) <= 1 and math.abs(l0 - 900) < 16,
    ("no se quedó donde lo dejaste: %s, %s"):format(tostring(barra:GetLeft()), tostring(barra:GetBottom())))
  K.MovibleVolver("bolsas.conjuntos")
  T(2)
  check(barra:GetLeft() >= pestanas[1]:GetRight() + 4, "«Volver a su lugar» no lo regresó junto a tu ventana")
  cf:Hide()
  T(1)
  Alfa.Set("bolsas.barraConjuntos", false)
  fondo:Hide()
end)

step("Lya: la tarjeta de los consejos cabe", function()
  local Ly = NS_OF("Alfa_Lya")
  check(Ly and Ly.L and Ly.L["Consejos"] ~= nil, "falta el texto «Consejos»")
end)

step("Lobos con Alfa sin hermandad: sin sección vacía", function()
  local Ma = NS_OF("Alfa_Manada")
  local Ce = Ma and Ma.Censo
  check(Ce and Ce.Abrir, "falta el censo de La Jauría")
  if not (Ce and Ce.Abrir) then return end
  IsInGuild = function() return false end
  Ce.Abrir()
  T(2)
  local v = rawget(_G, "AlfaManadaLobos")
  check(v and v:IsShown(), "la ventana no abrió")
  local vista = {}
  local function textos(f)
    for _, c in ipairs(f._children or {}) do
      if c._kind == "FontString" then
        if c:IsVisible() and c:GetText() then vista[#vista + 1] = c:GetText() end
      elseif c._kind ~= "Texture" and c:IsVisible() then textos(c) end
    end
  end
  if v then textos(v) end
  local todo = table.concat(vista, " | ")
  check(not todo:find("Preguntar ahora", 1, true), "sin hermandad sale «Preguntar ahora»: " .. todo)
  check(not todo:find(": 1", 1, true), "sin hermandad sale la insignia «versión: 1»: " .. todo)
  check(todo:find("hermandad", 1, true), "no dice que necesitas una hermandad")
  if v then v:Hide() end
end)

step("Dos pantallas: el asistente cabe con la interfaz grande", function()
  local Bv = NS_OF("Alfa_Bienvenida")
  local As = Bv and Bv.EscritorioAsistente
  check(As and As.Abrir, "falta el asistente de Dos pantallas")
  if not (As and As.Abrir) then return end
  PANTALLA_SIMULADA(1365, 768)
  As.Abrir()
  T(2)
  local v = rawget(_G, "AlfaEscritorioAsistente")
  check(v and v:IsShown(), "el asistente no abrió")
  if v then
    check(v:GetHeight() <= 768, "el asistente mide " .. tostring(v:GetHeight()) .. " de alto en una pantalla de 768")
    v:Hide()
  end
  PANTALLA_SIMULADA(1920, 1080)
  T(1)
end)

step("Paisaje y gráficos: la estrella dice qué marca", function()
  local Vi = NS_OF("Alfa_Vista")
  check(Vi and Vi.L and Vi.L["Lo marcado con %s también está en el menú del juego."], "falta el texto de la estrella")
end)

step("La flecha no repite el verbo («Ve a Ve al lugar 1»)", function()
  local E = Alfa.Engine
  local Ru = NS_OF("Alfa_Rutas")
  check(E and Ru and Ru.Guias, "falta el motor o las guías")
  if not (E and Ru and Ru.Guias) then return end
  local textos = { "Ve al lugar 1", "Habla con Gorn", "Vuelve a la posada", "Go to the camp", "El camino al norte" }
  local p = {}
  for i, t in ipairs(textos) do p[i] = { title = "Paso " .. i, goals = { { t = "goto", map = 1436, x = 10 + i * 3, y = 85, text = t } } } end
  local id = Ru.Guias.IdRuta("Prueba verbos")
  check(Ru.Guias.Instalar(Ru.Guias.Def(id, "Prueba verbos", p)), "no se instaló la guía")
  Ru.Guias.Abrir(id)
  T(3)
  for i, t in ipairs(textos) do
    local v = E.GetStepView(i)
    local g = v and v.goals and v.goals[1]
    check(g, "sin meta en el paso " .. i)
    if g then
      local dice = ((g.verb or "") ~= "" and (g.verb .. " ") or "") .. tostring(g.subject or g.text or "")
      if i <= 4 then
        check(not dice:find("Ve a Ve", 1, true) and not dice:find("Ve a Habla", 1, true) and not dice:find("Ve a Vuelve", 1, true)
          and not dice:find("Ve a Go", 1, true), "el verbo se repite: " .. dice)
        check(dice:find(t, 1, true), "no dice el texto de la guía: " .. dice)
      else
        check((g.verb or "") ~= "", "un lugar sin verbo ya no dice «Ve a»: " .. dice)
      end
    end
  end
end)

---------------------------------------------------------------------------
-- El audio (bug de Toxic: «ya no me deja regresar el audio»)
---------------------------------------------------------------------------
local P = NS_OF("Alfa_Pesca")
local Eq = P and P.Eq
local cv = {}
local escritas = {} -- lo que escribió Alfa (no el jugador)
local gC, sC = C_CVar.GetCVar, C_CVar.SetCVar
local NORMAL = { Sound_EnableAllSound = "1", Sound_MasterVolume = "0.8", Sound_EnableMusic = "1", Sound_MusicVolume = "0.5",
  Sound_EnableAmbience = "1", Sound_AmbienceVolume = "0.6", Sound_EnableSFX = "1", Sound_SFXVolume = "0.7",
  Sound_EnablePetSounds = "1", Sound_EnableSoundWhenGameIsInBG = "0", SoftTargetInteract = "1", SoftTargetInteractArc = "0",
  SoftTargetInteractRange = "10", SoftTargetIconGameObject = "0" }
local function reiniciarCVars() cv, escritas = {}, {} for k, v in pairs(NORMAL) do cv[k] = v end end
C_CVar.GetCVar = function(n) return cv[n] end
C_CVar.SetCVar = function(n, v) cv[n] = tostring(v) escritas[#escritas + 1] = n FIRE_EVENT("CVAR_UPDATE", n, tostring(v)) end
-- Como el menú de Opciones > Audio: escribe la CVar y avisa (con o sin el nombre).
local function jugador(n, v, sinNombre)
  cv[n] = v
  FIRE_EVENT("CVAR_UPDATE", sinNombre and "MUSIC_VOLUME" or n, v)
end
local cana = true
if Eq then Eq.CanaPuesta = function() return cana end end
local function sonidoSuelto()
  for k, v in pairs(NORMAL) do
    if k:find("^Sound_") and cv[k] ~= v then return k .. "=" .. tostring(cv[k]) end
  end
end

step("Audio: pescar y cerrar devuelve todo", function()
  check(P and P.AbrirModo and P.CerrarModo and P.DevolverSonido, "faltan las funciones de Pesca")
  if not (P and P.AbrirModo) then return end
  reiniciarCVars()
  Alfa.Set("pesca.activo", true)
  Alfa.Set("pesca.sonido", true)
  P.AbrirModo(true)
  check(cv.Sound_MusicVolume == "0", "la pesca no calló la música (" .. tostring(cv.Sound_MusicVolume) .. ")")
  P.CerrarModo(true, true)
  check(sonidoSuelto() == nil, "al cerrar la pesca no volvió: " .. tostring(sonidoSuelto()))
  check(next(AlfaNucleo.Datos("pesca").respaldo or {}) == nil, "quedó un respaldo de la cuenta")
end)

step("Audio: lo que subes tú mientras pescas manda (con o sin nombre en CVAR_UPDATE)", function()
  if not (P and P.AbrirModo) then return end
  for _, sinNombre in ipairs({ false, true }) do
    reiniciarCVars()
    P.AbrirModo(true)
    jugador("Sound_MusicVolume", "0.9", sinNombre)
    P.Aplicar()   -- otro lanzamiento
    P.Reaplicar() -- un ajuste de pesca cambió
    check(cv.Sound_MusicVolume == "0.9", "Alfa volvió a callar la música que subiste (" .. tostring(cv.Sound_MusicVolume) .. ")")
    FIRE_EVENT("PLAYER_REGEN_DISABLED") FIRE_EVENT("PLAYER_REGEN_ENABLED") T(1)
    check(cv.Sound_MusicVolume == "0.9", "tras el combate la música volvió a callarse")
    P.CerrarModo(true, true)
    check(cv.Sound_MusicVolume == "0.9", "al cerrar se puso la música de antes encima de la tuya")
    check(cv.Sound_EnableAmbience == "1", "el ambiente no volvió")
  end
end)

step("Audio: tras /reload sin caña, el modo no vuelve a callar nada", function()
  if not (P and P.AbrirModo) then return end
  reiniciarCVars()
  P.AbrirModo(true)
  FIRE_EVENT("PLAYER_LOGOUT")
  check(sonidoSuelto() == nil, "al salir no se devolvió: " .. tostring(sonidoSuelto()))
  -- Otra sesión: el modo quedó anotado, pero ya no traes la caña.
  cana = false
  P.CerrarModo(true, true) -- (el banco sigue en la misma sesión: se cierra a mano)
  AlfaNucleo.DatosPersonaje("pesca").modo = true
  escritas = {}
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true) T(3)
  check(not P.Modo(), "sin caña el modo pesca se abrió solo al entrar")
  for _, n in ipairs(escritas) do
    if n:find("^Sound_") then NOTE("1.4.0 bugs", "sin pescar se escribió " .. n) end
  end
  cana = true
end)

step("Audio: cierre de golpe, otro personaje y respaldo viejo por personaje", function()
  if not (P and P.AbrirModo) then return end
  reiniciarCVars()
  -- El respaldo viejo (1.3.x) estaba por personaje; el juego se cerró de golpe.
  local pj = AlfaNucleo.DatosPersonaje("pesca")
  pj.respaldo = { Sound_MusicVolume = "0.5", Sound_EnableAmbience = "1" }
  cv.Sound_MusicVolume, cv.Sound_EnableAmbience = "0", "0"
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false) T(2)
  check(cv.Sound_MusicVolume == "0.5" and cv.Sound_EnableAmbience == "1", "el respaldo viejo no devolvió la música y el ambiente")
  check(pj.respaldo == nil and AlfaNucleo.Datos("pesca").respaldo == nil, "el respaldo quedó guardado después de devolverlo")
end)

step("/alfa sonido devuelve el sonido y suelta el respaldo", function()
  if not (P and P.DevolverSonido) then return end
  reiniciarCVars()
  P.AbrirModo(true)
  check(cv.Sound_MusicVolume == "0", "la pesca no calló la música")
  Alfa.RunCommand("sonido")
  check(not P.Modo(), "/alfa sonido no cerró el modo pesca")
  check(sonidoSuelto() == nil, "/alfa sonido no devolvió: " .. tostring(sonidoSuelto()))
  check(AlfaNucleo.Datos("pesca").respaldo == nil, "/alfa sonido no soltó el respaldo")
  -- Sin respaldo y todo en cero (un respaldo envenenado de antes): valores normales.
  for _, k in ipairs({ "Sound_EnableAllSound", "Sound_MasterVolume", "Sound_EnableMusic", "Sound_MusicVolume", "Sound_EnableAmbience",
    "Sound_AmbienceVolume", "Sound_EnableSFX", "Sound_SFXVolume", "Sound_EnablePetSounds" }) do cv[k] = "0" end
  local cambio = P.DevolverSonido()
  check(cambio and #cambio == 9, "no devolvió los 9 valores: " .. tostring(cambio and #cambio))
  check(tonumber(cv.Sound_MusicVolume) > 0 and cv.Sound_EnableMusic == "1" and tonumber(cv.Sound_MasterVolume) > 0 and cv.Sound_EnableAllSound == "1",
    "con todo en cero el sonido sigue mudo")
  -- Ya bien: no cambia nada.
  local otra = P.DevolverSonido()
  check(otra and #otra == 0, "con el sonido bien, /alfa sonido cambió " .. tostring(otra and #otra))
end)
C_CVar.GetCVar, C_CVar.SetCVar = gC, sC

print(string.format("PRUEBA: 1.4.0 bugs, errores: %d", #ERRORS))
