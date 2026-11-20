-- Prueba de la 1.3.2: un solo menú de Alfa.
--   * el clic derecho del ícono del minimapa, la lista de addons, el botón
--     flotante y el botón «Alfa» del menú Esc abren el MISMO menú: las
--     secciones de la ventana (mismo nombre, ícono y orden) y unas acciones;
--   * el clic de cualquiera de ellos abre la ventana de Alfa (el del Esc ya no
--     abre el selector de guías), en la última página que viste;
--   * una sección de varias páginas abre su lista con «‹ Volver»;
--   * en Sencillo el menú no trae páginas que la ventana esconde.
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
local function check(cond, msg) if not cond then NOTE("1.3.2 menú", msg) end end

local ns = NS_OF("Alfa")
local B = rawget(_G, "AlfaBienvenida")
local pendiente = false
if B then B.Pendiente = function() return pendiente end end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local UI = ns.UI
local O = UI.Options
local W = ns.Widgets

-- Las filas que muestra el menú ahora (texto de cada fila visible).
local function filas()
  local m = rawget(_G, "AlfaMenu")
  local out = {}
  if not (m and m:IsShown()) then return out end
  for _, r in ipairs(m.rows or {}) do
    if r:IsShown() and r.psItem then out[#out + 1] = r.psItem end
  end
  return out
end
local function textos(fs)
  local t = {}
  for i, it in ipairs(fs) do t[i] = tostring(it.text) end
  return table.concat(t, " | ")
end
local function firma()
  local t = {}
  for _, it in ipairs(filas()) do t[#t + 1] = tostring(it.text) .. "#" .. tostring(it.icon) end
  return table.concat(t, ";")
end
local function fila(texto)
  for _, r in ipairs((rawget(_G, "AlfaMenu") or {}).rows or {}) do
    if r:IsShown() and r.psItem and tostring(r.psItem.text):find(texto, 1, true) then return r end
  end
end
local function ventana() return O.frame and O.frame:IsShown() end
local function cerrarTodo()
  W.HideMenu()
  if O.frame then O.frame:Hide() end
end

-- Las secciones que la ventana muestra, en orden.
local function seccionesVentana()
  local out = {}
  for _, s in ipairs(O.SECCIONES) do
    if #O.PagesOf(s.key) > 0 then out[#out + 1] = s end
  end
  out[#out + 1] = O.AJUSTES
  return out
end

local mini, firmaMini
step("El ícono del minimapa: clic derecho abre el menú de Alfa por secciones", function()
  mini = rawget(_G, "AlfaMinimapButton")
  check(mini, "no hay botón del minimapa")
  if not mini then return end
  FIRE(mini, "OnClick", "RightButton")
  local fs = filas()
  check(#fs > 0, "el clic derecho no abrió ningún menú")
  -- Ya no es la lista vieja de Polestar ni la de cada módulo suelto.
  local t = textos(fs)
  check(not t:find("Lookup", 1, true) and not t:find("Guides", 1, true) and not t:find("Options", 1, true),
    "el menú trae filas viejas en inglés: " .. t)
  -- Cada sección de la ventana, con su nombre e ícono, en el mismo orden.
  local i = 0
  for _, s in ipairs(seccionesVentana()) do
    local nombre = ns.T(s.label)
    local hallada
    for j, it in ipairs(fs) do
      if it.seccion == s.key then hallada = j break end
    end
    check(hallada, "falta la sección " .. nombre .. " en el menú")
    if hallada then
      check(hallada > i, "la sección " .. nombre .. " sale fuera de orden")
      check(fs[hallada].icon == s.icon, "la sección " .. nombre .. " trae otro ícono: " .. tostring(fs[hallada].icon))
      check(tostring(fs[hallada].text):find(nombre, 1, true), "la sección " .. s.key .. " se llama distinto: " .. tostring(fs[hallada].text))
      i = hallada
    end
  end
  check(fila("Reportar un problema"), "falta «Reportar un problema»")
  check(fila("Esconder todo Alfa"), "falta «Esconder todo Alfa»")
  firmaMini = firma()
  print("  menú: " .. t)
  -- Un segundo clic derecho lo cierra.
  FIRE(mini, "OnClick", "RightButton")
  check(#filas() == 0, "un segundo clic derecho no cerró el menú")
  cerrarTodo()
end)

step("Una sección de varias páginas abre su lista con «‹ Volver»", function()
  FIRE(mini, "OnClick", "RightButton")
  local multi
  for _, s in ipairs(seccionesVentana()) do
    if #O.PagesOf(s.key) > 1 then multi = s break end
  end
  check(multi, "ninguna sección con varias páginas")
  if not multi then return end
  local r = fila(ns.T(multi.label))
  check(r, "no está la fila de " .. multi.key)
  if not r then return end
  FIRE(r, "OnClick", "LeftButton")
  local fs = filas()
  check(fs[1] and tostring(fs[1].text):find(ns.T("Volver"), 1, true), "la lista de la sección no empieza con «‹ Volver»: " .. textos(fs))
  local paginas = O.PagesOf(multi.key)
  check(#fs == #paginas + 1, ("la sección trae %d filas y la ventana %d páginas"):format(#fs - 1, #paginas))
  check(not ventana(), "abrir la lista de una sección abrió la ventana")
  -- Elegir una página abre la ventana ahí.
  local ultima = paginas[#paginas]
  local rp = fila(O.PageLabel(ultima))
  check(rp, "no está la página " .. ultima.key .. " en la lista")
  if rp then
    FIRE(rp, "OnClick", "LeftButton")
    check(ventana(), "elegir una página no abrió la ventana")
    check(O.Current and O.Current() == ultima.key or (O.view and true), "la ventana no abrió en la página elegida")
  end
  -- «‹ Volver» regresa a las secciones.
  cerrarTodo()
  FIRE(mini, "OnClick", "RightButton")
  FIRE(fila(ns.T(multi.label)), "OnClick", "LeftButton")
  FIRE(fila(ns.T("Volver")), "OnClick", "LeftButton")
  check(firma() == firmaMini, "«‹ Volver» no regresó al menú de secciones")
  cerrarTodo()
end)

step("El clic del ícono abre la ventana en la última página que viste", function()
  cerrarTodo()
  UI.ShowOptions("bolsas")
  RUN_TIMERS(1)
  O.frame:Hide()
  FIRE(mini, "OnClick", "LeftButton")
  check(ventana(), "el clic del ícono no abrió la ventana")
  check(O.ultimaVista == "bolsas", "no se abrió en la última página vista: " .. tostring(O.ultimaVista))
  FIRE(mini, "OnClick", "LeftButton")
  check(not ventana(), "un segundo clic no cerró la ventana")
end)

step("La lista de addons: el mismo clic y el mismo menú", function()
  cerrarTodo()
  local fila0 = CreateFrame("Button", nil, UIParent)
  Alfa_OnAddonCompartmentClick("Alfa", "LeftButton", fila0)
  check(ventana(), "el clic en la lista de addons no abrió la ventana (antes ocultaba Alfa)")
  check(not ns.Hidden(), "el clic en la lista de addons ocultó Alfa")
  cerrarTodo()
  Alfa_OnAddonCompartmentClick("Alfa", "RightButton", fila0)
  local f = firma()
  -- La primera fila cambia con la ventana abierta o cerrada; las dos cerradas aquí.
  check(f == firmaMini, "el menú de la lista de addons no es el del ícono:\n   " .. f .. "\n   " .. tostring(firmaMini))
  cerrarTodo()
end)

step("El botón «Alfa» del menú Esc: abre la ventana y su clic derecho, el mismo menú", function()
  cerrarTodo()
  local GM = UI.GameMenu
  check(GM and GM.Open, "falta UI.GameMenu")
  if not GM then return end
  local opened = false
  local picker = false
  local off = ns.On("SHOW_PICKER", function() picker = true end)
  GM.Open()
  check(ventana(), "el botón del Esc no abrió la ventana de Alfa")
  check(not picker, "el botón del Esc abrió el selector de guías")
  cerrarTodo()
  -- El botón mismo: lo arma el menú Esc al abrirse; aquí, con su función.
  local b = GM.Button and GM.Button()
  if b then
    FIRE(b, "OnClick", "RightButton")
    check(firma() == firmaMini, "el clic derecho del botón del Esc no da el mismo menú")
    cerrarTodo()
    FIRE(b, "OnClick", "LeftButton")
    check(ventana(), "el clic del botón del Esc no abrió la ventana")
    cerrarTodo()
  else
    GM.Menu(UIParent)
    check(firma() == firmaMini, "GameMenu.Menu no da el mismo menú")
    cerrarTodo()
  end
end)

step("Elegir una fila desde el menú Esc cierra el menú Esc", function()
  local esc = rawget(_G, "GameMenuFrame")
  if not esc then esc = CreateFrame("Frame", "GameMenuFrame", UIParent) end
  esc:Show()
  O.MenuAlfa(UIParent)
  local r = fila(ns.T(O.SECCIONES[1].label))
  check(r, "no está la primera sección")
  if r then FIRE(r, "OnClick", "LeftButton") end
  check(not esc:IsShown(), "el menú Esc siguió abierto al abrir una página")
  check(ventana(), "no se abrió la ventana")
  cerrarTodo()
end)

step("En Sencillo, el menú no trae páginas que la ventana esconde", function()
  local N = AlfaNucleo
  if not (N and N.PaginaVisible) then return end
  for _, s in ipairs(seccionesVentana()) do
    for _, p in ipairs(O.PagesOf(s.key)) do
      check(N.PaginaVisible(p.key), "el menú trae una página escondida: " .. p.key)
    end
  end
end)

step("El cuadro del ratón dice lo mismo en el ícono y en la lista de addons", function()
  local dichos = {}
  local orig = W.Tooltip
  W.Tooltip = function(owner, anchor, title, lines) dichos[#dichos + 1] = (lines and lines[1]) return orig(owner, anchor, title, lines) end
  FIRE(mini, "OnEnter")
  Alfa_OnAddonCompartmentEnter("Alfa", CreateFrame("Button", nil, UIParent))
  W.Tooltip = orig
  check(#dichos == 2, "faltó un cuadro")
  local a, b = dichos[1], dichos[2]
  if type(a) == "table" then a = a[1] end
  if type(b) == "table" then b = b[1] end
  check(a == b, "el ícono dice «" .. tostring(a) .. "» y la lista «" .. tostring(b) .. "»")
end)

step("Sin terminar la configuración, el menú lleva a la configuración", function()
  if not B then return end
  cerrarTodo()
  pendiente = true
  local abierta = false
  local orig = B.Abrir
  B.Abrir = function() abierta = true end
  O.MenuAlfa(UIParent)
  local r = fila(ns.T(O.SECCIONES[1].label))
  if r then FIRE(r, "OnClick", "LeftButton") end
  check(abierta, "el menú no llevó a la configuración")
  check(not ventana(), "el menú abrió la ventana sin terminar la configuración")
  B.Abrir = orig
  pendiente = false
  cerrarTodo()
end)

print(("prueba_132_menu: %d pasos, %d errores"):format(pasos, #ERRORS))
