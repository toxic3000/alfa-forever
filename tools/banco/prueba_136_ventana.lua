-- Prueba de la 1.3.6: la ventana de Alfa y su buscador.
local pasos = 0
local function step(nombre, fn)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function falla(msg) NOTE("ventana 1.3.6", msg) end
local function T(n) RUN_TIMERS(n or 2) end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local A, N = Alfa, AlfaNucleo
local B = AlfaBienvenida
N.Datos("bienvenida").respondio = B and B.VERSION or 99
N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
print("errores al entrar:", #ERRORS)
local O = A.UI.Options

A.Fire("SHOW_OPTIONS", "inicio")
T(2)
local win = O.frame

step("el buscador espera a que dejes de teclear", function()
  local veces = 0
  local orig = O.Search
  O.Search = function(...) veces = veces + 1 if DEPURAR then print(debug.traceback("busca", 2):sub(1, 600)) end return orig(...) end
  local caja = win.Search
  for _, t in ipairs({ "p", "pe", "pes", "pesc", "pesca" }) do
    caja:SetText(t)
    local fn = caja:GetScript("OnTextChanged")
    if fn then fn(caja, true) end
  end
  if veces > 0 then falla("el buscador buscó " .. veces .. " veces mientras tecleabas") end
  T(3)
  if veces ~= 1 then falla("al dejar de teclear buscó " .. veces .. " veces (debía 1)") end
  O.Search = orig
end)

step("buscar «pesca» encuentra la página Pesca", function()
  O.SetQuery("pesca")
  local hay = false
  for _, p in ipairs(O.SearchPages()) do if p.key == "pesca" then hay = true end end
  if not hay then falla("«pesca» no encontró la página Pesca") end
  O.SetQuery("talentos")
  local tal = false
  for _, p in ipairs(O.SearchPages()) do if p.key == "builds" or p.key == "talentos" then tal = true end end
  if not tal then falla("«talentos» no encontró la página de Talentos") end
end)

step("con una sola letra no busca, y lo dice", function()
  local veces = 0
  local orig = O.Search
  O.Search = function(...) veces = veces + 1 return orig(...) end
  O.SetQuery("b")
  O.Search = orig
  if veces ~= 0 then falla("con una letra buscó igual") end
end)

step("sin resultados: «No encontré» y preguntarle a Lya", function()
  O.SetQuery("zzqqxx")
  local textos = {}
  for _, f in ipairs(ALL_FRAMES()) do
    if f:IsVisible() and f.GetText then
      local t = f:GetText()
      if type(t) == "string" then textos[#textos + 1] = t end
    end
  end
  local todo = table.concat(textos, "\n")
  if not todo:find("No encontré", 1, true) then falla("sin resultados no dice «No encontré»") end
  if rawget(_G, "AlfaLya") and not todo:find("Lya", 1, true) then falla("sin resultados no ofrece preguntarle a Lya") end
  O.SetQuery("")
end)

step("al volver a una página, donde ibas", function()
  A.Fire("SHOW_OPTIONS", "manada")
  local sc = win.Scroll
  W_ALTO = sc:GetHeight()
  local h = O.view and O.view:GetHeight() or 0
  if h <= (sc:GetHeight() or 0) + 40 then print("  (La Jauría cabe sin desplazar: nada que recordar)") return end
  sc:SetVerticalScroll(40)
  A.Fire("SHOW_OPTIONS", "inicio")
  A.Fire("SHOW_OPTIONS", "manada")
  if math.abs((sc:GetVerticalScroll() or 0) - 40) > 1 then falla("al volver a La Jauría no regresó a donde ibas (" .. tostring(sc:GetVerticalScroll()) .. ")") end
end)

step("la página que vuelves a abrir no se esconde y se muestra", function()
  A.Fire("SHOW_OPTIONS", "comodidades")
  local v = O.view
  local escondida = 0
  local hh = v.Hide
  v.Hide = function(self) escondida = escondida + 1 return hh(self) end
  A.Fire("SHOW_OPTIONS", "comodidades")
  v.Hide = hh
  if escondida > 0 then falla("la página se escondió para volver a mostrarse") end
end)

step("el pie no se rehace al cambiar de página", function()
  local W = A.Widgets or A.W
  local veces = 0
  local orig = W and W.ShellFooter
  if not orig then print("  (sin W.ShellFooter a la vista)") return end
  W.ShellFooter = function(...) veces = veces + 1 return orig(...) end
  for _, id in ipairs({ "inicio", "rutas", "bolsas", "pesca", "rutas" }) do A.Fire("SHOW_OPTIONS", id) end
  W.ShellFooter = orig
  if veces > 3 then falla("el pie se rehízo " .. veces .. " veces en 5 cambios de página") end
end)

step("el selector de guías espera a que dejes de teclear", function()
  -- En Alfa, la biblioteca de Rutas reemplaza al selector del motor: aquí se
  -- abre el del motor a propósito.
  local R = A.Reemplazos
  local ll = R and R.Llamar
  if R then R.Llamar = function() return false end end
  A.UI.ShowPicker()
  if R then R.Llamar = ll end
  T(2)
  local P = A.UI.Picker
  local pw = P and P.frame
  if not (pw and pw.Search) then print("  (sin selector de guías)") return end
  local veces = 0
  local orig = P.Render
  P.Render = function(...) veces = veces + 1 return orig(...) end
  for _, t in ipairs({ "d", "du", "dur", "duro", "durot" }) do
    pw.Search:SetText(t)
    local fn = pw.Search:GetScript("OnTextChanged")
    if fn then fn(pw.Search, true) end
  end
  local mientras = veces
  T(3)
  P.Render = orig
  if mientras > 0 then falla("el selector se repintó " .. mientras .. " veces mientras tecleabas") end
  pw:Hide()
end)


step("escribir y borrar rápido no deja una búsqueda vieja", function()
  local caja = win.Search
  local function teclear(t)
    caja:SetText(t)
    local fn = caja:GetScript("OnTextChanged")
    if fn then fn(caja, true) end
  end
  teclear("pesca") T(3)
  teclear("pescax") teclear("pesca")
  T(3)
  local res = O.results
  if win.Search:GetText() == "pesca" and res and res.count == 0 and #O.SearchPages() == 0 then
    falla("con «pesca» en la caja se ve la búsqueda vieja «pescax»")
  end
  O.SetQuery("") caja:SetText("")
end)

step("elegir una página justo después de teclear no la tapa la búsqueda", function()
  local caja = win.Search
  caja:SetText("bolsas")
  local fn = caja:GetScript("OnTextChanged")
  if fn then fn(caja, true) end
  A.Fire("SHOW_OPTIONS", "pesca")
  T(3)
  if O.page and O.page.key ~= "pesca" then falla("la búsqueda tapó la página elegida") end
  if (caja:GetText() or "") ~= "" then falla("al elegir una página, la caja del buscador quedó con texto") end
end)

print(("PRUEBA: ventana 1.3.6, %d pasos, errores: %d"):format(pasos, #ERRORS))
