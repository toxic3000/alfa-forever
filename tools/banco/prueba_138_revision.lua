-- Prueba de la 1.3.8, arreglos de la revisión independiente (tools/prueba.py
-- la corre con las demás). Los números son los de la lista de arreglos:
--   1. el adorno de temporada con la ruta bien escrita;
--   2. un susurro sin marca (Alfa 1.3.7) pasa salvo que el remitente sea de la otra facción;
--   3. el canal viejo «AlfaJauria» se calla y se deja al volver a entrar;
--   4. «A pelear» con dos armas del mismo nombre: cada una por su bolsa y casilla;
--   5. la escala de UnitHealthPercent (0–1 o 0–100) y las curvas en esa escala;
--   6. la flecha vuelve al aterrizar solo si de verdad volaste;
--   7. la pausa cuenta desde que empezaste a jugar y anota la última vez;
--   8. un plan largo no se corta a media meta;
--   9. «Me apunto» solo de tu hermandad;
--   10/15. el anuncio que no sale avisa (alPerder) y se olvida el suceso;
--   11. lo urgente (prioridad 1, «siempre») nunca se calla con N.YaSeVio;
--   13. el panel Mapa no vuelve a abrir el mapa que cerraste;
--   14. el cursor en unidades de UIParent con el escritorio movido;
--   16. (UltimaVez) se revisa leyendo el código: la carta por vencer;
--   17. si aplicar la prueba de pantallas falla, se vuelve a como estaba;
--   19. Mayús+clic con candado separa el montón;
--   20. el botón de dos renglones sobrevive a un repintado.
SNAPSHOTS = {}
local function step(nombre, fn, ...)
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.3.8 revision", msg) end end
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = rawget(t, k) } rawset(t, k, v) end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do rawset(t, k, a.v) end
  if not ok then error(e, 0) end
end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
NOW = NOW + 120

local N = AlfaNucleo
local A = N.A
local K = N.Kit
local Nav = A.Nav
local Ma = NS_OF("Alfa_Manada")
local Ru = NS_OF("Alfa_Rutas")
local Ly = NS_OF("Alfa_Lya")
local Pe = NS_OF("Alfa_Pesca")
local Cu = NS_OF("Alfa_Curacion")
local Bi = NS_OF("Alfa_Bienvenida")
local Bo = NS_OF("Alfa_Bolsas")
if N.Entrando then N.Entrando = function() return false end end
if A.UI.Options.frame then A.UI.Options.frame:Hide() end

---------------------------------------------------------------------------
step("1. El adorno de temporada", function()
  local t = K.TEMPORADAS and K.TEMPORADAS[1]
  check(t and t.adorno == "Interface\\AddOns\\Alfa_Nucleo\\Media\\temporada-calabaza",
    "la ruta del adorno está mal: " .. tostring(t and t.adorno))
end)

---------------------------------------------------------------------------
step("2. Un susurro viejo (sin marca) pasa", function()
  con(N, { FaccionDe = function() return nil end }, function()
    local sigue, limpio = N.FiltroFaccion("1U|5|3575", "WHISPER", "Desconocido")
    check(sigue == true and limpio == "1U|5|3575", "un susurro sin marca de alguien sin facción conocida no pasó")
  end)
  local otra = N.FaccionLetra() == "H" and "A" or "H"
  con(N, { FaccionDe = function() return otra end }, function()
    check(N.FiltroFaccion("1U|5|3575", "WHISPER", "Ajeno") == false, "un susurro de la otra facción pasó")
  end)
  check(N.FiltroFaccion("1U|5|3575", "CHANNEL", "Desconocido") == false, "lo sin marca por el canal pasó")
end)

---------------------------------------------------------------------------
step("3. El canal viejo se calla y se deja", function()
  local Cn = Ma.Canal
  check(Cn.EsViejo("AlfaJauria") and Cn.EsViejo("5. AlfaJauria") and not Cn.EsViejo("AlfaJauriaH"), "no reconoce el canal viejo")
  local dejados = {}
  con(_G, { LeaveChannelByName = function(n) dejados[#dejados + 1] = n end }, function()
    FIRE_EVENT("CHAT_MSG_CHANNEL_NOTICE", "YOU_JOINED", "", "", "5. AlfaJauria", "", "", 0, 5, "AlfaJauria")
  end)
  check(dejados[1] == "AlfaJauria", "al volver a entrar al canal viejo no se deja")
end)

---------------------------------------------------------------------------
step("4. Dos armas del mismo nombre", function()
  local Eq = Pe.Eq
  local hoja = "|cffffffff|Hitem:2488::::::::|h[Hoja]|h|r"
  local bolsas = { [0] = { [3] = hoja, [7] = hoja } }
  local CC = {
    GetContainerNumSlots = function(b) return bolsas[b] and 16 or 0 end,
    GetContainerItemLink = function(b, s) return bolsas[b] and bolsas[b][s] or nil end,
  }
  con(_G, { C_Container = setmetatable(CC, { __index = rawget(_G, "C_Container") }),
    GetInventoryItemLink = function(_, r) if r == 16 then return "|cffffffff|Hitem:6256::::::::|h[Caña]|h|r" end end }, function()
    con(Eq, { Armas = function() return {
        { ranura = 16, enlace = hoja, nombre = "Hoja" }, { ranura = 17, enlace = hoja, nombre = "Hoja" } } end }, function()
      local m = Eq.MacroArmas() or ""
      check(m:find("/equipslot 16 0 3", 1, true) and m:find("/equipslot 17 0 7", 1, true),
        "con dos armas iguales la macro no va por bolsa y casilla: " .. m)
    end)
    con(Eq, { Armas = function() return {
        { ranura = 16, enlace = hoja, nombre = "Hoja" }, { ranura = 17, enlace = "|cffffffff|Hitem:1::::::::|h[Daga]|h|r", nombre = "Daga" } } end }, function()
      local m = Eq.MacroArmas() or ""
      check(m:find("/equipslot 16 Hoja", 1, true) and m:find("/equipslot 17 Daga", 1, true), "con armas distintas cambió la macro: " .. m)
    end)
  end)
end)

---------------------------------------------------------------------------
step("5. La escala de UnitHealthPercent", function()
  local curvas = {}
  local function curva()
    local c = { puntos = {} }
    function c:SetType() end
    function c:AddPoint(x) self.puntos[#self.puntos + 1] = x end
    curvas[#curvas + 1] = c
    return c
  end
  local d = Cu.Datos()
  local antes = d.escalaVida
  for _, caso in ipairs({ { 0.5, 1 }, { 50, 100 } }) do
    con(_G, { UnitHealth = function() return 500 end, UnitHealthMax = function() return 1000 end,
      UnitHealthPercent = function(u, p, c) return caso[1] end, InCombatLockdown = function() return false end,
      C_CurveUtil = { CreateColorCurve = curva, CreateCurve = curva }, CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }, function()
      d.escalaVida = nil
      Cu.OlvidarCurvas()
      check(Cu.DetectarEscalaVida() == caso[2] and Cu.EscalaVida() == caso[2], "no detectó la escala " .. caso[2])
      curvas = {}
      local cs = Cu.CurvasPeligro()
      check(cs and curvas[1] and math.abs(curvas[1].puntos[2] - 0.35 * caso[2]) < 1e-6,
        "el umbral de peligro no quedó en la escala " .. caso[2] .. ": " .. tostring(curvas[1] and curvas[1].puntos[2]))
      curvas = {}
      Cu.CurvaTanque()
      check(curvas[1] and math.abs(curvas[1].puntos[2] - 0.4 * caso[2]) < 1e-6, "el umbral del tanque no quedó en la escala " .. caso[2])
      curvas = {}
      Cu.CurvaVida("normal")
      check(curvas[1] and curvas[1].puntos[#curvas[1].puntos] == caso[2], "la curva de la vida no quedó en la escala " .. caso[2])
    end)
  end
  -- Sin poder leer la vida (secreta), no se decide nada.
  con(_G, { UnitHealth = function() return SECRETO(500) end, UnitHealthMax = function() return 1000 end,
    UnitHealthPercent = function() return 0.5 end }, function()
    check(Cu.DetectarEscalaVida() == nil, "con la vida secreta decidió una escala")
  end)
  d.escalaVida = antes
  Cu.OlvidarCurvas()
end)

---------------------------------------------------------------------------
step("6. La flecha vuelve solo si volaste", function()
  local Gf = Ru.Grifo
  Gf.Reiniciar()
  local puesto
  local enTaxi = false
  con(Nav, { SetTarget = function(map, x, y, label) puesto = { map, x, y, label } return true end }, function()
    con(_G, { UnitOnTaxi = function() return enTaxi end }, function()
      check(Gf.Llevar({ clave = "prueba", propio = true, nodo = "Villa", punto = { map = 1429, x = 40, y = 50 },
        destino = { kind = "manual", map = 1436, x = 10, y = 20, label = "Destino" } }), "no te llevó al maestro de vuelo")
      -- Un aturdimiento camino al maestro de vuelo: la flecha se queda.
      FIRE_EVENT("PLAYER_CONTROL_LOST")
      RUN_TIMERS(3)
      FIRE_EVENT("PLAYER_CONTROL_GAINED")
      RUN_TIMERS(3)
      check(Gf.Vuelta() ~= nil and puesto and puesto[1] == 1429, "un aturdimiento regresó la flecha")
      -- El vuelo de verdad.
      enTaxi = true
      FIRE_EVENT("PLAYER_CONTROL_LOST")
      RUN_TIMERS(3)
      enTaxi = false
      FIRE_EVENT("PLAYER_CONTROL_GAINED")
      RUN_TIMERS(3)
      check(Gf.Vuelta() == nil and puesto and puesto[1] == 1436, "al aterrizar la flecha no volvió a tu destino")
    end)
  end)
  Gf.Reiniciar()
end)

---------------------------------------------------------------------------
step("7. La pausa cuenta desde el principio", function()
  local Pa, Ce = Ly.Pausa, Ly.Cerebro
  Pa.Reiniciar()
  local reloj = 1700000000
  local dicho
  con(_G, { GetServerTime = function() return reloj end }, function()
    con(Ce, { Decir = function(c) dicho = c return true end }, function()
      Pa.NuevoTramo(reloj)
      reloj = reloj + 2 * 3600 + 5
      check(Pa.Revisar() and dicho, "a las 2 horas no sugiere la pausa")
      -- «Recuérdamelo en 30 min»
      local accion = dicho and dicho.acciones and dicho.acciones[1]
      if accion then accion.fn() end
      dicho = nil
      reloj = reloj + 30 * 60 + 5
      check(Pa.Revisar() and dicho and dicho.texto:find("2 h", 1, true), "tras «en 30 min» no cuenta desde el principio: " .. tostring(dicho and dicho.texto))
      check(not (dicho and dicho.texto:find("Llevas 30", 1, true)), "dice «Llevas 30 min» con 2 h 30 jugando")
      -- La última vez que te vio jugando.
      Pa.Observar()
      check(N.DatosPersonaje(Ly.ID).ultimaVez == reloj, "la última vez no se anotó")
    end)
  end)
  Pa.Reiniciar()
end)

---------------------------------------------------------------------------
step("8. Un plan largo no se corta a media meta", function()
  local Co = Ma.Compartir
  local metas = {}
  for i = 1, 25 do metas[i] = { tipo = "nota", texto = string.rep("Nota larga " .. i .. " ", 4) } end
  local texto, puestas, total = Co.Codificar("Plan largo", metas, 6 * 180)
  check(#texto <= 6 * 180, "el plan se pasa del tope: " .. #texto)
  check(puestas < total and total == 25, ("no dice cuántas metas cupieron: %s de %s"):format(tostring(puestas), tostring(total)))
  local _, de = Co.Decodificar(texto)
  check(type(de) == "table" and #de == puestas, "al decodificar no vuelven las metas enteras: " .. tostring(type(de) == "table" and #de))
end)

---------------------------------------------------------------------------
step("9. «Me apunto» solo de tu hermandad", function()
  local Tb = Ma.Tablon
  Tb.Olvidar()
  con(Tb, { Mio = function() return { desde = 1, texto = "Minas" } end }, function()
    con(Ma.Ficha, { DeMiHermandad = function(n) return n == "Amiga" end }, function()
      check(not Tb.SeApunta("extrano", "Extraño"), "se tomó un «me apunto» de alguien que no es de tu hermandad")
      check(Tb.SeApunta("amiga", "Amiga"), "no se tomó el «me apunto» de tu hermandad")
    end)
  end)
  Tb.Olvidar()
end)

---------------------------------------------------------------------------
step("10/15. El anuncio que no sale lo avisa", function()
  check(type(N.OlvidarSuceso) == "function", "falta N.OlvidarSuceso")
  N.Suceso("prueba.peligro", 600)
  N.OlvidarSuceso("prueba.peligro")
  check(N.Suceso("prueba.peligro", 600) == true, "el suceso olvidado sigue anotado")
  local perdido = 0
  K.Anuncio({ titulo = "Zona de prueba", estilo = "zona", caduca = GetTime() - 1, alPerder = function() perdido = perdido + 1 end })
  check(perdido == 1, "un anuncio caducado no avisó que no salió")
  check(N.Zonas == nil or type(N.Zonas.DevolverJuego) == "function", "falta Z.DevolverJuego")
end)

---------------------------------------------------------------------------
step("11. Lo urgente no se calla", function()
  N.Visto("Te atacan prueba", "aviso")
  local r = K.Aviso({ id = "prueba.urgente", titulo = "Te atacan", texto = "prueba", prioridad = 1, importante = "siempre", lya = false })
  check(r ~= false, "lo urgente se calló por N.YaSeVio")
end)

---------------------------------------------------------------------------
step("13. El panel Mapa no reabre lo que cerraste", function()
  local Es = Bi.Escritorio
  if not (Es and Es.TomarMapa) then return end
  local mapa = CreateFrame("Frame", "AlfaMundoMapaPrueba", UIParent)
  mapa:Hide()
  local abiertos = 0
  local Mu = { Abrir = function() abiertos = abiertos + 1 mapa:Show() end, Cerrar = function() mapa:Hide() end }
  local p = CreateFrame("Frame", nil, UIParent)
  p.Cuerpo = CreateFrame("Frame", nil, p)
  con(_G, { AlfaMundo = Mu, AlfaMundoMapa = mapa }, function()
    check(Es.TomarMapa(p) and abiertos == 1, "el panel no puso el mapa la primera vez")
    mapa:Hide() -- lo cierras tú
    check(not Es.TomarMapa(p) and abiertos == 1, "el panel volvió a abrir el mapa que cerraste")
    check(not Es.TomarMapa(p) and abiertos == 1, "el panel volvió a abrir el mapa a los 5 s")
    check(Es.TomarMapa(p, true) and abiertos == 2, "«Ver el mapa aquí» no lo abre")
    Es.SoltarMapa()
  end)
end)

---------------------------------------------------------------------------
step("14. El cursor con el escritorio movido", function()
  con(UIParent, { GetLeft = function() return 500 end, GetBottom = function() return 40 end,
    GetEffectiveScale = function() return 2 end }, function()
    con(_G, { GetCursorPosition = function() return 1200, 400 end }, function()
      local x, y = K.CursorEnUI()
      check(x == 100 and y == 160, ("el cursor no se mide desde UIParent: %s, %s"):format(tostring(x), tostring(y)))
    end)
  end)
end)

---------------------------------------------------------------------------
step("17. Si aplicar falla, vuelve como estaba", function()
  local Es = Bi.Escritorio
  if not (Es and Es.Probar) then return end
  if Es.Probando() then Es.Rechazar(true) end
  con(_G, { geterrorhandler = function() return function() end end }, function()
    con(Es, { Aplicar = function() error("falla de prueba") end }, function()
      check(Es.Probar({ lado = "derecha" }) == false, "con la falla dijo que se probó")
    end)
  end)
  check(not Es.Probando(), "la prueba quedó a medias tras la falla")
  local f = rawget(_G, "AlfaEscritorioConfirmar")
  check(not (f and f:IsShown()), "el cuadro «¿Se ve bien?» se quedó a la vista")
end)

---------------------------------------------------------------------------
step("19. Mayús+clic separa el montón con candado", function()
  local Cd = Bo.Candado
  local capa = CreateFrame("Button", nil, UIParent)
  capa.alfaBolsa, capa.alfaCasilla = 0, 4
  local pedido
  con(_G, { IsModifiedClick = function(q) return q == "SPLITSTACK" end,
    OpenStackSplitFrame = function(n, dueno) pedido = { n, dueno } end,
    C_Container = setmetatable({ GetContainerItemInfo = function() return { itemID = 2589, stackCount = 12, hyperlink = "|Hitem:2589|h[Paño]|h" } end },
      { __index = rawget(_G, "C_Container") }) }, function()
    Cd.ClicCapa(capa, "LeftButton")
  end)
  check(pedido and pedido[1] == 12 and pedido[2] == capa and type(capa.SplitStack) == "function", "Mayús+clic no abrió el separador del montón")
end)

---------------------------------------------------------------------------
step("20. El botón de dos renglones tras repintar", function()
  local padre = CreateFrame("Frame", nil, UIParent)
  local b = K.Boton(padre, "x", function() end)
  K.BotonQueQuepa(b, "Un texto muy largo que no cabe en un botón chiquito de nada", nil, 60)
  check(b.alfaDosLineas == 60, "no quedó en dos renglones")
  check(type(K.BotonDosLineas) == "function", "falta K.BotonDosLineas")
  if K.Repintar then pcall(K.Repintar) end
  check(math.floor(b:GetWidth() + 0.5) == 60, "al repintar el botón volvió a un renglón: " .. tostring(b:GetWidth()))
end)
