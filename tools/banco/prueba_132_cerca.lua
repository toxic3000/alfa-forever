-- Prueba de la 1.3.2 (lo que pidió Toxic al probarla en el juego):
--   * un lobo que usa Alfa entra a la vista: sale el anuncio de Alfa, corto
--     (como mucho 10 s), con su nombre; no de ti, ni de tu grupo, ni de
--     quien no usa Alfa, ni dos veces seguidas, ni en combate;
--   * el fundador también sale con el anuncio de Alfa (no con la tarjeta
--     vieja que se quedaba), y corto;
--   * el buzón ya no saca su barra.
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
local function check(cond, msg) if not cond then NOTE("1.3.2 cerca", msg) end end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local ns = NS_OF("Alfa")
local MN = NS_OF("Alfa_Manada")
local N = AlfaNucleo
local A = N.A
local K = N.Kit

local anuncios = {}
local anuncioReal = K.Anuncio
K.Anuncio = function(o) anuncios[#anuncios + 1] = o return true end

-- Unidades de mentira: unidad -> nombre completo.
local unidades = {}
local fullReal = A.Compat.UnitFullName
A.Compat.UnitFullName = function(u) local n = unidades[u] if n then return n end return fullReal(u) end
local esJugadorReal, esUnidadReal = UnitIsPlayer, UnitIsUnit
UnitIsPlayer = function(u) if unidades[u] then return true end return esJugadorReal and esJugadorReal(u) end
UnitIsUnit = function(a, b) if unidades[a] and b == "player" then return false end return esUnidadReal and esUnidadReal(a, b) end
local enInstancia = false
local instReal = IsInInstance
IsInInstance = function() if enInstancia then return true, "party" end return false, "none" end

step("Un lobo que usa Alfa entra a la vista: anuncio corto con su nombre", function()
  local Ce, G, U = MN.Cerca, MN.Gente, MN.U
  check(Ce and Ce.Revisar, "falta Cerca.lua") if not Ce then return end
  check(A.Get("manada.lobosCerca") == true, "el aviso de lobos cerca no viene prendido")
  G.Oido(U.Clave("Lunaria"), "Lunaria", "CHANNEL", {})
  unidades.nameplate3 = "Lunaria"
  anuncios = {}
  FIRE_EVENT("NAME_PLATE_UNIT_ADDED", "nameplate3")
  check(#anuncios == 1, "no salió el anuncio de un lobo cerca (" .. #anuncios .. ")")
  local o = anuncios[1]
  if o then
    check(o.titulo == "Lunaria", "el anuncio no trae su nombre: " .. tostring(o.titulo))
    check(o.sobre == "Un lobo de La Jauría anda cerca", "el anuncio no dice que es de la manada: " .. tostring(o.sobre))
    check((o.segundos or 99) <= 10, "el anuncio dura más de 10 s: " .. tostring(o.segundos))
  end
  -- La misma persona otra vez: nada.
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  unidades.target = "Lunaria"
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  check(#anuncios == 1, "avisó dos veces de la misma persona")
end)

step("Quien no usa Alfa, tú o alguien en combate: nada", function()
  local Ce, G, U = MN.Cerca, MN.Gente, MN.U
  Ce.Olvidar()
  anuncios = {}
  unidades.mouseover = "Desconocido"
  FIRE_EVENT("UPDATE_MOUSEOVER_UNIT")
  check(#anuncios == 0, "avisó de alguien que no usa Alfa")
  -- En una instancia, no.
  G.Oido(U.Clave("Colmillo"), "Colmillo", "GUILD", {})
  unidades.mouseover = "Colmillo"
  enInstancia = true
  FIRE_EVENT("UPDATE_MOUSEOVER_UNIT")
  check(#anuncios == 0, "avisó dentro de una instancia")
  enInstancia = false
  -- Apagado, no.
  A.Set("manada.lobosCerca", false)
  FIRE_EVENT("UPDATE_MOUSEOVER_UNIT")
  check(#anuncios == 0, "avisó con el ajuste apagado")
  A.Set("manada.lobosCerca", nil)
  FIRE_EVENT("UPDATE_MOUSEOVER_UNIT")
  check(#anuncios == 1, "con el ajuste prendido no avisó de Colmillo")
end)

step("El fundador sale con el anuncio de Alfa, corto", function()
  local T = ns.Rares and ns.Rares.Toast
  check(T and T.Show, "falta la tarjeta de raros") if not (T and T.Show) then return end
  anuncios = {}
  T.Show({ kind = "founder", name = ns.Rares.FOUNDER, zone = "Orgrimmar" })
  check(#anuncios == 1, "el fundador no salió con el anuncio de Alfa")
  local o = anuncios[1]
  if o then
    check((o.segundos or 99) <= 10, "el anuncio del fundador dura más de 10 s")
    check(o.titulo == ns.Rares.FOUNDER, "el anuncio del fundador no trae su nombre")
  end
  check(not (T.frame and T.frame:IsShown()), "salió también la tarjeta vieja")
end)

step("El buzón ya no saca su barra", function()
  local C = NS_OF("Alfa_Comercio")
  local Bz = C and C.Buzon
  if not Bz then return end
  if not rawget(_G, "MailFrame") then CreateFrame("Frame", "MailFrame", UIParent) end
  FIRE_EVENT("MAIL_SHOW")
  RUN_TIMERS(2)
  check(Bz.Barra() == nil, "salió la barra bajo el buzón")
  FIRE_EVENT("MAIL_CLOSED")
end)

K.Anuncio = anuncioReal
A.Compat.UnitFullName = fullReal
UnitIsPlayer, UnitIsUnit, IsInInstance = esJugadorReal, esUnidadReal, instReal
print(("prueba_132_cerca: %d pasos, %d errores"):format(pasos, #ERRORS))
