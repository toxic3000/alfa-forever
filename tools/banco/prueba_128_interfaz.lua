-- Prueba de la 1.2.8, la interfaz (los puntos 16 a 20):
--   * Acerca de Alfa: la historia, el Discord en un cuadro para copiar y la versión;
--   * Estrellas guía dice que son los créditos de Polestar;
--   * carga ligera: el ritmo de la ventana de guía no carga el Codex, y la base
--     de Recolección viene compacta y se lee por zona;
--   * los nodos de Recolección en el mapa de Alfa (agrupados, con tope);
--   * Buscar en todo Alfa: misiones, raros y PNJ debajo de los ajustes.
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
local function check(cond, msg) if not cond then NOTE("1.2.8", msg) end end

local ns = NS_OF("Alfa")
local A = AlfaNucleo.A
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

step("Carga ligera: el ritmo no carga el Codex", function()
  local C, Lv = ns.Codex, ns.Levels
  check(C and Lv and Lv.Pace, "falta el Codex o Levels")
  local cargas = 0
  local isL, load = C.IsLoaded, C.Load
  C.IsLoaded = function() return false end
  C.Load = function() cargas = cargas + 1 return false end
  local ok, e = pcall(Lv.Pace)
  C.IsLoaded, C.Load = isL, load
  check(ok, "Levels.Pace falló: " .. tostring(e))
  check(cargas == 0, "el ritmo de la ventana de guía cargó el Codex")
  check(Lv.ligero == nil, "Levels.ligero quedó puesto")
end)

step("Carga ligera: la base de Recolección viene compacta", function()
  local M = NS_OF("Alfa_Recoleccion")
  local R = M.R
  local hay, textos = 0, 0
  for _, porMapa in pairs(M.BASE) do
    for _, v in pairs(porMapa) do
      hay = hay + 1
      if type(v) == "string" then textos = textos + 1 end
    end
  end
  check(hay > 0 and textos == hay, "la base no viene compacta (" .. textos .. " de " .. hay .. ")")
  local base = R.Conteos()
  check(base > 1000, "la base cuenta pocos puntos: " .. tostring(base))
  local p = R.PuntosDe("0.25,0.5,0.75,0.125")
  check(#p == 4 and p[2] == 0.5 and p[4] == 0.125, "PuntosDe no lee el texto")
  local idx = R.IndiceSiHay(1419) or R.IndiceSiHay(1411) or R.IndiceSiHay(1413)
  check(idx and idx.n > 0, "una zona con nodos no armó su índice")
end)

step("Recolección en el mapa de Alfa: agrupada y con tope", function()
  local M = NS_OF("Alfa_Recoleccion")
  local MM = M.MapaMundo
  check(MM and MM.Refrescar, "falta MapaMundo")
  local P = A.Pins
  local capas = {}
  local set = P.SetLayer
  P.SetLayer = function(id, pins, o) capas[id] = pins return set(id, pins, o) end
  local Mu = AlfaMundo
  local zonas = Mu.ZonasALaVista
  Mu.ZonasALaVista = function() return { 1419, 1413, 1411 } end
  MM.Refrescar(true)
  Mu.ZonasALaVista = zonas
  P.SetLayer = set
  local total, conCuadro = 0, 0
  for id, pins in pairs(capas) do
    check(id:find("^recoleccion%."), "capa con otro nombre: " .. id)
    check(#pins <= 3 * 28 * 28, "demasiados puntos en " .. id .. ": " .. #pins)
    for _, pin in ipairs(pins) do
      total = total + 1
      if type(pin.tooltip) == "function" then conCuadro = conCuadro + 1 end
    end
  end
  check(next(capas) ~= nil, "Recolección no publicó sus capas")
  check(total == conCuadro, "un punto sin su cuadro con el nombre")
end)

local UI = ns.UI
local O = UI.Options

step("Acerca de Alfa: historia, Discord y versión", function()
  UI.ShowOptions("about")
  RUN_TIMERS(1)
  local v = O.view
  check(v and v.DiscordBox, "Acerca de no tiene el cuadro del Discord")
  if v and v.DiscordBox then
    check(v.DiscordBox:GetText() == "https://discord.gg/hUNjA6BJwh", "el cuadro no trae la invitación: " .. tostring(v.DiscordBox:GetText()))
  end
  local textos = {}
  for _, r in ipairs({ v:GetRegions() }) do
    if r.GetText and r:GetText() then textos[#textos + 1] = r:GetText() end
  end
  local todo = table.concat(textos, "\n")
  check(todo:find("perrita de Toxic", 1, true), "falta la historia de Lya")
  check(todo:find("Polestar, de fitzforge", 1, true), "falta en qué se basa Alfa")
  check(todo:find("ForeverLevelingBiS", 1, true), "faltan los créditos de los datos")
  check(not todo:lower():find("paypal") and not todo:lower():find("don[ae]"), "Acerca de habla de donaciones")
end)

step("Estrellas guía: créditos de Polestar", function()
  UI.ShowOptions("thanks")
  RUN_TIMERS(1)
  local v = O.view
  local textos = {}
  for _, r in ipairs({ v:GetRegions() }) do
    if r.GetText and r:GetText() then textos[#textos + 1] = r:GetText() end
  end
  local todo = table.concat(textos, "\n")
  check(todo:find("Polestar", 1, true), "Estrellas guía no dice que son de Polestar")
  check(not todo:find("hacer posible Alfa", 1, true), "Estrellas guía sigue diciendo que son de Alfa")
end)

step("Buscar en todo Alfa", function()
  -- Los nombres de las marcas de banda, como en el juego (el banco no los trae).
  for i = 1, 8 do if type(rawget(_G, "RAID_TARGET_" .. i)) ~= "string" then rawset(_G, "RAID_TARGET_" .. i, "Marca " .. i) end end
  local C = ns.Codex
  C.Load()
  check(C.IsLoaded(), "el Codex no cargó")
  -- Las primeras letras de una misión y de un raro del Codex.
  local mision, raro
  C.Each("quest", function(id, name) if type(name) == "string" and #name >= 8 then mision = name return false end end)
  C.Each("rare", function(id, name) if type(name) == "string" and #name >= 6 then raro = { id = id, name = name } return false end end)
  check(mision and raro, "el Codex no trae misiones o raros")
  local g = O.BuscarTodo(mision:sub(1, 6))
  local hayMision = false
  for _, x in ipairs(g) do
    check(#x.filas <= 5, "un grupo con más de 5")
    if x.kind == "quest" then hayMision = true end
  end
  check(hayMision, "no encontró la misión " .. mision)
  check(#O.BuscarTodo("ab") == 0, "buscó con menos de 3 letras")
  local gr = O.BuscarTodo(raro.name)
  local r
  for _, x in ipairs(gr) do if x.kind == "rare" then r = x.filas[1] end end
  check(r, "no encontró el raro " .. raro.name)
  if r then
    local E = AlfaEnciclopedia
    local fl, ab = E.Flecha, E.Abrir
    local puso
    E.Flecha = function(k, id) puso = k .. ":" .. tostring(id) return fl(k, id) end
    O.AbrirTodo(r)
    E.Flecha = fl
    check(puso == "rare:" .. tostring(r.id), "el clic en un raro no puso la flecha")
  end
  -- En la ventana: un momento después de escribir, el bloque aparece.
  UI.ShowOptions("about")
  O.SetQuery(mision:sub(1, 6))
  RUN_TIMERS(2)
  local sv = O.Todo
  check(sv.query == mision:sub(1, 6) and sv.grupos and #sv.grupos > 0, "la ventana no buscó en todo Alfa")
  O.SetQuery("")
end)

print(string.format("PRUEBA: 1.2.8 interfaz, %d pasos, %d errores", pasos, #ERRORS))
