-- Prueba de la 1.2.0 (tools/prueba.py la corre con las demás prueba_*.lua):
--   * Insignias de La Jauría (Alfa_Manada/Insignias.lua): con dos nombres de
--     prueba puestos en la lista ("alfa" con reino y "jauria" sin reino), se
--     encuentran sin importar mayúsculas, acentos ni el reino (sin reino =
--     tu reino), y nadie más; un nombre solo, sin apellido ni reino, o un
--     rango que no existe, no cuentan;
--   * el cuadro de un jugador con insignia gana exactamente una línea (por el
--     gancho de unidades del motor, aunque el juego lo llame dos veces) y el
--     de los demás, o el de una criatura, ninguna;
--   * en el mapa, quien comparte (manada.jauria) sale con la huella pequeña,
--     del color de su clase o del verde de Alfa; tu grupo (manada.grupo)
--     sigue con su marca grande; los de la lista llevan el aro de su rango;
--   * la página de La Jauría pone el lobo junto al nombre de quien lo tiene;
--   * al dejar de compartir, nadie de la manada queda en el mapa.
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
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
local A = Alfa
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local M = NS_OF("Alfa_Manada")
local I = M.Insignias
local L = M.L
local REINO = GetRealmName() -- "Forever" en el banco

-- Los dos nombres de prueba: una Alfa con reino y uno de La Jauría sin reino.
local ALFA = "Rocío Luna-" .. REINO
local JAURIA = "Bruno Garra"
local TEXTO_ALFA, TEXTO_JAURIA = L["Alfa de La Jauría"], L["De La Jauría"]

local function cerca(a, b) return math.abs((a or -1) - (b or -2)) < 0.01 end
local function mismoColor(c, r, g, b) return type(c) == "table" and cerca(c[1], r) and cerca(c[2], g) and cerca(c[3], b) end

-- Las líneas de insignia en una lista de textos.
local function insignias(lineas)
  local n, cual = 0, nil
  for _, t in ipairs(lineas) do
    if type(t) == "string" and (t:find(TEXTO_ALFA, 1, true) or t:find(TEXTO_JAURIA, 1, true)) then
      n = n + 1
      cual = t:find(TEXTO_ALFA, 1, true) and "alfa" or "jauria"
    end
  end
  return n, cual
end

-- Un cuadro de mentira que apunta lo que se le escribe.
local function cuadroFalso()
  local tip = { lineas = {} }
  function tip:SetText(t) self.lineas[#self.lineas + 1] = t end
  function tip:AddLine(t) self.lineas[#self.lineas + 1] = t end
  function tip:AddDoubleLine(t) self.lineas[#self.lineas + 1] = t end
  function tip:NumLines() return #self.lineas end
  return tip
end

local agregados = {}
step("Insignias: dos nombres de prueba en la lista", function()
  if not (I and I.LISTA and I.De and I.Rehacer) then error("falta Alfa_Manada/Insignias.lua (M.Insignias)") end
  local puestos = {
    [ALFA] = "alfa",
    [JAURIA] = "Jauría",       -- con acento y mayúscula: cuenta como "jauria"
    ["Solito"] = "alfa",       -- un nombre solo, sin apellido ni reino: no cuenta
    ["Mal Rango-" .. REINO] = "rey", -- un rango que no existe: no cuenta
  }
  for k, v in pairs(puestos) do
    if I.LISTA[k] == nil then
      I.LISTA[k] = v
      agregados[#agregados + 1] = k
    end
  end
  I.Rehacer()
  if not I.Hay() then error("con nombres en la lista, I.Hay() dice que no hay nadie") end
end)

step("Insignias: se encuentran sin mayúsculas, acentos ni reino", function()
  local casos = {
    { ALFA, "alfa" }, { "ROCIO LUNA-" .. REINO:upper(), "alfa" }, { "rocío luna", "alfa" }, { "Rocio  Luna", "alfa" },
    { "Rocío Luna-OtroReino", nil }, -- con otro reino: es otra persona
    { "Rocío", nil },
    { JAURIA, "jauria" }, { "BRUNÓ GÁRRA", "jauria" }, { "Bruno Garra-OtroReino", "jauria" }, -- sin reino: cualquiera
    { "Solito", nil }, { "Solito-" .. REINO, nil },
    { "Mal Rango", nil },
    { "Lobato", nil }, { "Pedro Páramo", nil }, { "", nil },
  }
  for _, c in ipairs(casos) do
    local v = I.De(c[1])
    if v ~= c[2] then error(("«%s» dio %s, se esperaba %s"):format(c[1], tostring(v), tostring(c[2]))) end
  end
  if I.De(nil) ~= nil or I.De(42) ~= nil then error("un nombre que no es texto dio insignia") end
  if not (AlfaManada and AlfaManada.Insignia) then error("falta AlfaManada.Insignia") end
  if AlfaManada.Insignia("rocio luna") ~= "alfa" then error("AlfaManada.Insignia no encontró a la Alfa") end
  local e = AlfaManada.EstiloInsignia and AlfaManada.EstiloInsignia("alfa")
  if not (e and e.texto == TEXTO_ALFA and type(e.icono) == "string" and e.icono:find("ic%-lobo") and type(e.color) == "table") then
    error("AlfaManada.EstiloInsignia(\"alfa\") salió mal")
  end
  if AlfaManada.EstiloInsignia("rey") ~= nil then error("un rango que no existe tiene estilo") end
  local ic = I.Icono("alfa")
  if not (ic:find("^|T") and ic:find("ic%-lobo") and ic:find(":242:208:107|t$")) then error("el lobo de la Alfa no salió en oro: " .. ic) end
  if I.Icono("nada") ~= "" then error("un rango que no existe dibujó un lobo") end
end)

---------------------------------------------------------------------------
-- El cuadro del jugador
---------------------------------------------------------------------------

-- Unidades de prueba: nombre como lo da Forever ("Nombre Apellido", sin
-- reino) y si es jugador.
local UNIDADES = {
  mouseover = { "Rocío Luna", true },
  focus = { "Bruno Garra", true },
  target = { "Pedro Páramo", true },
  npc = { "Bruno Garra", false }, -- una criatura que se llama igual: no
}
local guardado = {}
local function poner(nombre, fn)
  if guardado[nombre] == nil then guardado[nombre] = { rawget(_G, nombre) } end
  _G[nombre] = fn
end
local function restaurar()
  for nombre, v in pairs(guardado) do _G[nombre] = v[1] end
  guardado = {}
end

local unitNameViejo = UnitName
local function simularUnidades()
  poner("UnitName", function(u)
    local d = UNIDADES[u]
    if d then return d[1], nil end
    return unitNameViejo(u)
  end)
  poner("UnitIsPlayer", function(u)
    local d = UNIDADES[u]
    if d then return d[2] end
    return u == "player"
  end)
  poner("UnitExists", function(u) return u == "player" or UNIDADES[u] ~= nil end)
  poner("UnitGUID", function(u)
    if UNIDADES[u] then return "Prueba-" .. u end
    return "Player-1-0001"
  end)
  poner("UnitTokenFromGUID", function(g) return type(g) == "string" and g:match("^Prueba%-(.+)$") or nil end)
end

-- Arma el cuadro de una unidad como el juego: lo limpia y llama a los
-- ganchos de unidades del motor (las veces que se pida). -> líneas escritas
local tipViejo
local function cuadroDe(unit, veces)
  local tip = GameTooltip
  if not tipViejo then tipViejo = { AddLine = tip.AddLine, AddDoubleLine = tip.AddDoubleLine, NumLines = tip.NumLines, GetUnit = rawget(tip, "GetUnit") } end
  local lineas = {}
  tip.AddLine = function(_, t) lineas[#lineas + 1] = t end
  tip.AddDoubleLine = function(_, t) lineas[#lineas + 1] = t end
  tip.NumLines = function() return 1 + #lineas end
  tip.GetUnit = function() return UNIDADES[unit] and UNIDADES[unit][1], unit end
  FIRE(tip, "OnTooltipCleared")
  local H = A.Hooks
  for _ = 1, veces or 1 do
    if H and H.OnUnitTooltip then
      H.OnUnitTooltip(tip, { guid = "Prueba-" .. unit })
    else
      I.AlCuadro(tip, unit)
    end
  end
  return lineas
end

step("Cuadro del jugador: una línea para quien tiene insignia, ninguna para los demás", function()
  simularUnidades()
  local ok, err = pcall(function()
    if not (A.Hooks and A.Hooks.OnUnitTooltip) then print("AVISO: el motor no expone Hooks.OnUnitTooltip; se prueba I.AlCuadro directo") end
    local n, cual = insignias(cuadroDe("mouseover"))
    if n ~= 1 or cual ~= "alfa" then error(("la Alfa sacó %d líneas de insignia (%s); se esperaba 1 de Alfa"):format(n, tostring(cual))) end
    -- El juego puede llamar al gancho dos veces para el mismo cuadro: sigue siendo una.
    n = insignias(cuadroDe("mouseover", 2))
    if n ~= 1 then error(("con el gancho dos veces, la Alfa sacó %d líneas de insignia"):format(n)) end
    n, cual = insignias(cuadroDe("focus"))
    if n ~= 1 or cual ~= "jauria" then error(("el de La Jauría sacó %d líneas de insignia (%s)"):format(n, tostring(cual))) end
    n = insignias(cuadroDe("target"))
    if n ~= 0 then error(("alguien sin insignia sacó %d líneas de insignia"):format(n)) end
    n = insignias(cuadroDe("npc"))
    if n ~= 0 then error("una criatura con el nombre de alguien de la lista sacó la insignia") end
    -- La línea misma: el lobo y el rango, en su color.
    local tip = cuadroFalso()
    if not I.AlCuadro(tip, "mouseover") then error("I.AlCuadro no puso la línea de la Alfa") end
    if #tip.lineas ~= 1 or not tip.lineas[1]:find("^|T.-ic%-lobo.-|t " .. TEXTO_ALFA .. "$") then error("la línea salió así: " .. tostring(tip.lineas[1])) end
    if I.AlCuadro(cuadroFalso(), "target") then error("I.AlCuadro puso línea para alguien sin insignia") end
    if I.AlCuadro(cuadroFalso(), nil) then error("I.AlCuadro puso línea sin unidad") end
  end)
  restaurar()
  if tipViejo then
    for k, v in pairs(tipViejo) do GameTooltip[k] = v end
    if tipViejo.GetUnit == nil then GameTooltip.GetUnit = nil end
  end
  if not ok then error(err, 0) end
end)

---------------------------------------------------------------------------
-- El mapa: la huella de quien comparte y el aro de las insignias
---------------------------------------------------------------------------

local G, Mapa = M.Gente, M.Mapa
local ORO = { 0.949, 0.816, 0.42 }
local VERDE = I.VERDE

local function pinDe(capa, nombre)
  local pines = A.Pins.GetLayer(capa)
  for _, p in ipairs(type(pines) == "table" and pines or {}) do
    if p.badge == nombre then return p end
  end
  return nil
end

step("Mapa: quien comparte sale con la huella y los de la lista con su aro", function()
  AlfaManada.Compartir(true)
  T(2)
  -- Tu grupo: la Alfa (posición del juego).
  poner("IsInGroup", function() return true end)
  poner("IsInRaid", function() return false end)
  poner("GetNumSubgroupMembers", function() return 1 end)
  poner("UnitIsUnit", function(a, b) return a == b end)
  poner("UnitName", function(u)
    if u == "party1" then return "Rocío Luna", nil end
    return unitNameViejo(u)
  end)
  local ok, err = pcall(function()
    G.LeerGrupo()
    -- Quienes comparten (mensajes de Alfa): uno de La Jauría de otro reino,
    -- uno sin clase conocida y una maga, los dos sin insignia.
    G.Oido("bruno garra otroreino", "Bruno Garra-OtroReino", "canal", { map = 1411, x = 40, y = 40, nivel = 20, clase = "WARRIOR" })
    G.Oido("pedro paramo", "Pedro Páramo", "canal", { map = 1411, x = 45, y = 42, nivel = 12 })
    G.Oido("ines colmillo", "Inés Colmillo", "canal", { map = 1411, x = 55, y = 60, nivel = 30, clase = "MAGE" })
    Mapa.Refrescar(true)
    T(1)
    local manada = A.Pins.GetLayer("manada.jauria")
    if type(manada) ~= "table" or #manada ~= 3 then error("la capa manada.jauria tiene " .. tostring(type(manada) == "table" and #manada or manada) .. " pines; se esperaban 3") end
    local grupo = pinDe("manada.grupo", "Rocío")
    if not grupo then error("tu grupo no salió en manada.grupo") end
    if grupo.icon ~= "map:pin-small" or grupo.size ~= 15 then error("tu grupo ya no tiene su marca: " .. tostring(grupo.icon) .. " " .. tostring(grupo.size)) end
    if not mismoColor(grupo.ring, ORO[1], ORO[2], ORO[3]) then error("la Alfa de tu grupo no tiene el aro de oro") end
    for _, p in ipairs(manada) do
      if type(p.icon) ~= "string" or not p.icon:find("[\\/]ic%-huella$") then error(tostring(p.badge) .. ": no es la huella: " .. tostring(p.icon)) end
      if not (p.size and p.size < grupo.size and (p.minimapSize or p.size) < (grupo.minimapSize or grupo.size)) then
        error(tostring(p.badge) .. ": la huella no es más chica que la marca de tu grupo")
      end
    end
    local bruno, pedro, ines = pinDe("manada.jauria", "Bruno"), pinDe("manada.jauria", "Pedro"), pinDe("manada.jauria", "Inés")
    if not (bruno and pedro and ines) then error("faltan pines de la manada (Bruno, Pedro, Inés)") end
    if not mismoColor(bruno.ring, VERDE[1], VERDE[2], VERDE[3]) then error("el de La Jauría no tiene el aro verde") end
    if pedro.ring or ines.ring then error("alguien sin insignia tiene aro") end
    if not (bruno.priority > pedro.priority) then error("el de La Jauría no queda encima de los demás") end
    if not mismoColor(pedro.color, VERDE[1], VERDE[2], VERDE[3]) then error("sin clase, la huella no es verde de Alfa") end
    local r, g, b = Mapa.ColorHuella("MAGE")
    if not mismoColor(ines.color, r, g, b) or mismoColor(ines.color, VERDE[1], VERDE[2], VERDE[3]) then error("la huella de la maga no tiene el color de su clase") end
    -- El cuadro del pin dice la insignia (una vez) solo de quien la tiene.
    local tb, tp = cuadroFalso(), cuadroFalso()
    bruno.tooltip(tb)
    pedro.tooltip(tp)
    local n, cual = insignias(tb.lineas)
    if n ~= 1 or cual ~= "jauria" then error(("el cuadro del pin del de La Jauría tiene %d líneas de insignia"):format(n)) end
    if insignias(tp.lineas) ~= 0 then error("el cuadro del pin de alguien sin insignia la dice") end
  end)
  if not ok then
    restaurar()
    error(err, 0)
  end
end)

step("Página: el lobo junto al nombre de quien tiene insignia", function()
  A.Fire("SHOW_OPTIONS", "manada")
  T(2)
  M.Avisar()
  T(1)
  local ui = M.Pagina.ui
  local rej = ui and ui.tablero and ui.tablero.Rejilla
  if not rej then error("no se armó la página de La Jauría") end
  local vistos = {}
  for _, c in ipairs(rej.elementos or {}) do
    local d = c.alfaDatos
    local f = d and d.persona
    if f then vistos[f.nombre] = d end
  end
  local conLobo = function(d) return d and type(d.titulo) == "string" and d.titulo:find("ic%-lobo", 1) ~= nil end
  local bruno, pedro = vistos["Bruno Garra-OtroReino"] or vistos["Bruno Garra"], vistos["Pedro Páramo"]
  local rocio = vistos["Rocío Luna"]
  if not (bruno and pedro and rocio) then
    local n = {}
    for k in pairs(vistos) do n[#n + 1] = k end
    error("faltan tarjetas en la página; hay: " .. table.concat(n, ", "))
  end
  if not conLobo(rocio) or not conLobo(bruno) then error("el lobo no salió junto al nombre de quien tiene insignia") end
  if conLobo(pedro) then error("el lobo salió junto al nombre de alguien sin insignia") end
  if not (rocio.ayuda and rocio.ayuda:find(TEXTO_ALFA, 1, true)) then error("la tarjeta de la Alfa no dice qué es el lobo al pasar el ratón") end
  if pedro.ayuda then error("la tarjeta de alguien sin insignia tiene ayuda de insignia") end
  local f = A.UI and A.UI.Options and A.UI.Options.frame
  if f then f:Hide() end
end)

step("Mapa: al dejar de compartir, nadie de la manada queda", function()
  AlfaManada.Compartir(false)
  T(3)
  Mapa.Refrescar(true)
  T(1)
  local manada = A.Pins.GetLayer("manada.jauria")
  if type(manada) == "table" and #manada > 0 then error(#manada .. " pines de la manada siguen en el mapa sin compartir") end
  if not pinDe("manada.grupo", "Rocío") then error("tu grupo dejó de verse al dejar de compartir (se ve siempre)") end
end)

step("Insignias: la lista vuelve como estaba", function()
  restaurar()
  for _, k in ipairs(agregados) do I.LISTA[k] = nil end
  I.Rehacer()
  G.LeerGrupo()
  -- Con la lista vacía (como sale de fábrica) nadie tiene insignia.
  if next(I.LISTA) == nil and (I.Hay() or I.De(ALFA) or I.De(JAURIA)) then error("con la lista vacía alguien sigue con insignia") end
end)

print("PRUEBA: 1.2.0 insignias, " .. pasos .. " pasos, " .. #ERRORS .. " errores")
