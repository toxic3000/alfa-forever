-- Prueba de la 1.3.2, el marco de Ajustes y la bienvenida (tools/prueba.py la
-- corre con las demás prueba_*.lua):
--   * «Restablecer página» de Estilo y sonido: no toca «Cómo ves Alfa», devuelve
--     el estilo y su acento, y su aviso dice exactamente qué vuelve;
--   * el paso «Elige tus extras» de la configuración: ningún texto se corta
--     (también con textos un 70 % más largos, como en alemán o ruso);
--   * el buscador de Ajustes: el grupo que se llama como lo buscado va
--     primero, y cada grupo muestra unos pocos con «N más»;
--   * Ajustes en Sencillo: sin las páginas avanzadas del motor; «Comodidades ›
--     Minimapa y coordenadas»; el botón del minimapa en un solo lugar;
--   * relojes que duermen: el de los botones del minimapa solo durante el
--     fundido; los de Recolección, solo con su mapa a la vista.
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
local function check(cond, msg) if not cond then NOTE("1.3.2 ajustes", msg) end end

Alfa.Hidden = function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local A, N, K = Alfa, AlfaNucleo, AlfaNucleo.Kit
local O = A.UI.Options
local B = NS_OF("Alfa_Bienvenida")

-- Los hijos de un marco (el banco los guarda en _children), a fondo.
local function cada(f, fn)
  for _, h in ipairs(rawget(f, "_children") or {}) do fn(h) cada(h, fn) end
end
local function textoVisible(raiz, t)
  local hallado
  cada(raiz, function(h)
    if not hallado and h._kind == "FontString" and h.GetText and h:GetText() == t and h:IsVisible() then hallado = h end
  end)
  return hallado
end
-- El botón (con OnClick) que lleva ese texto.
local function boton(raiz, t)
  local hallado
  cada(raiz, function(h)
    if hallado or not (h.GetScript and h:GetScript("OnClick") and h:IsVisible()) then return end
    cada(h, function(x) if x._kind == "FontString" and x.GetText and x:GetText() == t then hallado = h end end)
  end)
  return hallado
end

---------------------------------------------------------------------------
-- 1. «Restablecer página» de Estilo y sonido
---------------------------------------------------------------------------
step("Restablecer Estilo y sonido: no toca «Cómo ves Alfa» y devuelve el estilo y su acento", function()
  A.Set("bienvenida.modo", "completo")
  A.Set("ui.skin", "cristal")
  A.Set("ui.accent", { 0.9, 0.5, 0.6 })
  A.Set("nucleo.letraGrande", true)
  A.Set("bienvenida.aullido", false)
  local claves = O.PageKeys and O.PageKeys("bienvenida") or {}
  local esta = false
  for _, k in ipairs(claves) do if k == "bienvenida.modo" then esta = true end end
  check(type(O.PageKeys) == "function" and not esta, "«Restablecer página» incluye «Cómo ves Alfa» (bienvenida.modo)")
  local texto = O.ResetText and O.ResetText("bienvenida") or ""
  check(texto:find("Cómo ves Alfa", 1, true) and texto:find("Letra más grande", 1, true) and texto:find("estilo", 1, true),
    "el aviso no dice exactamente qué vuelve: " .. tostring(texto))
  O.ResetPage("bienvenida")
  check(A.Get("bienvenida.modo") == "completo", "restablecer la página cambió «Cómo ves Alfa» a " .. tostring(A.Get("bienvenida.modo")))
  check(A.Get("ui.skin") == "alfa", "el estilo no volvió a Alfa: " .. tostring(A.Get("ui.skin")))
  check(A.Get("ui.accent") == A.GetDefault("ui.accent"), "el color de acento no volvió al de fábrica: " .. tostring(A.Get("ui.accent")))
  check(A.Get("nucleo.letraGrande") == false and A.Get("bienvenida.aullido") == true, "los ajustes de la página no volvieron")
  -- Las demás páginas siguen con el aviso de siempre.
  local otro = O.ResetText and O.ResetText("comodidades") or ""
  check(otro ~= "" and not otro:find("Cómo ves Alfa", 1, true), "otra página tomó el aviso de Estilo y sonido")
end)

---------------------------------------------------------------------------
-- 2. «Elige tus extras»: sin textos cortados
---------------------------------------------------------------------------
-- Renglones que pide el texto de una tarjeta a su ancho (como mide el banco).
local function renglones(fs)
  local w = rawget(fs, "_w") or 0
  if w <= 0 then return 1 end
  local ancho = fs:GetUnboundedStringWidth()
  return 1 + math.floor(ancho / w)
end
local function tarjetasExtras()
  local v = _G.AlfaBienvenidaVentana
  local out = {}
  if not v then return out end
  cada(v, function(h)
    local d = rawget(h, "alfaDatos")
    if type(d) == "table" and d.elegida ~= nil and rawget(h, "Texto") and h:IsVisible() then out[#out + 1] = h end
  end)
  return out
end

step("Configuración: en «Elige tus extras» ningún texto se corta", function()
  B.AbrirVentana("asistente") RUN_TIMERS(1)
  local v = _G.AlfaBienvenidaVentana
  local a = v and v.alfaAsistente
  check(a ~= nil, "no se abrió la configuración") if not a then return end
  local i
  for j, p in ipairs(a.pasos) do if p.id == "extras" then i = j end end
  check(i ~= nil, "no está el paso de los extras") if not i then return end
  a:Ir(i) RUN_TIMERS(1)
  local cartas = tarjetasExtras()
  check(#cartas >= 4, "no salieron las tarjetas de los extras (" .. #cartas .. ")")
  for _, c in ipairs(cartas) do
    local fs = c.Texto
    local tope = rawget(fs, "_max") or 0
    check(tope == 0 or renglones(fs) <= tope, "se corta: " .. tostring(fs:GetText()))
  end
  -- Con un texto un 70 % más largo (alemán, ruso o francés), tampoco.
  local ancho = 0
  for _, c in ipairs(cartas) do
    local d = c.alfaDatos
    local largo = d.texto .. " " .. d.texto:sub(1, math.floor(#d.texto * 0.7))
    local copia = {}
    for k, x in pairs(d) do copia[k] = x end
    copia.texto = largo
    c:Set(copia)
    ancho = c:GetWidth()
    c:Acomodar(ancho)
    local tope = rawget(c.Texto, "_max") or 0
    check(tope == 0 or renglones(c.Texto) <= tope, "con un texto más largo se corta: " .. largo:sub(1, 60))
    c:Set(d)
  end
  v:Hide()
end)

---------------------------------------------------------------------------
-- 3. El buscador de Ajustes
---------------------------------------------------------------------------
step("Buscador: el grupo que se llama como lo buscado va primero", function()
  local g = O.Search("minimapa")
  check(g[1] and g[1].title:find("Minimapa y coordenadas", 1, true), "«minimapa» no lleva primero a Minimapa y coordenadas: " .. tostring(g[1] and g[1].title))
  g = O.Search("sonido")
  check(g[1] and g[1].title:find("Estilo y sonido", 1, true), "«sonido» no lleva primero a Estilo y sonido: " .. tostring(g[1] and g[1].title))
  g = O.Search("mercaderes")
  check(g[1] and g[1].title:find("Mercaderes", 1, true), "«mercaderes» no lleva primero a su pestaña: " .. tostring(g[1] and g[1].title))
end)

step("Buscador: unos pocos por grupo, con «N más»", function()
  A.Fire("SHOW_OPTIONS", "bienvenida") RUN_TIMERS(1)
  local win = O.frame or _G.AlfaOptions
  check(win and win:IsShown(), "no se abrió la ventana de Alfa") if not win then return end
  O.SetQuery("tecla")
  RUN_TIMERS(1)
  local res = O.results or {}
  local grande
  for _, gr in ipairs(res.groups or {}) do if #gr.controls > 5 then grande = gr break end end
  check(grande ~= nil, "ningún grupo con muchos resultados para probar") if not grande then return end
  local mas = textoVisible(win, string.format("%d más", #grande.controls - 4))
  check(mas ~= nil, "un grupo con " .. #grande.controls .. " resultados no muestra «N más»")
  local b = boton(win, "Ver todos")
  check(b ~= nil, "no está el botón «Ver todos»")
  if b then
    local antes = 0
    cada(win, function(h) if h._kind == "FontString" and h:IsVisible() and h:GetText() == "Ver todos" then antes = antes + 1 end end)
    b:GetScript("OnClick")(b, "LeftButton")
    RUN_TIMERS(1)
    local despues = 0
    cada(win, function(h) if h._kind == "FontString" and h:IsVisible() and h:GetText() == "Ver todos" then despues = despues + 1 end end)
    check(despues == antes - 1, "«Ver todos» no abrió su grupo (" .. antes .. " -> " .. despues .. ")")
  end
  O.SetQuery("")
  win:Hide()
end)

---------------------------------------------------------------------------
-- 4. Ajustes en Sencillo y el mapa en un solo lugar
---------------------------------------------------------------------------
step("Sencillo: sin las páginas avanzadas del motor; Completo: con ellas", function()
  A.Set("bienvenida.modo", "sencillo")
  for _, k in ipairs({ "recorder", "guidepacks", "integrations", "gamepad", "thanks" }) do
    check(not N.PaginaVisible(k), "con Sencillo sale la página avanzada " .. k)
  end
  for _, k in ipairs({ "bienvenida", "comodidades", "questing", "about" }) do
    check(N.PaginaVisible(k), "con Sencillo no sale la página " .. k)
  end
  A.Set("bienvenida.modo", "completo")
  for _, k in ipairs({ "recorder", "guidepacks", "integrations", "gamepad", "thanks" }) do
    check(N.PaginaVisible(k), "con Completo no sale la página " .. k)
  end
end)

step("Comodidades › Minimapa y coordenadas, y el botón del minimapa en un solo lugar", function()
  local tabs
  for _, p in ipairs(O.Pages()) do if p.key == "comodidades" then tabs = p.tabs end end
  local nombres = table.concat(tabs or {}, ", ")
  check(nombres:find("Minimapa y coordenadas", 1, true), "Comodidades no tiene «Minimapa y coordenadas»: " .. nombres)
  local veces, donde = 0, {}
  for _, p in ipairs(O.Pages()) do
    local e = O.Estructura(p.key)
    for _, t in ipairs(e and e.tabs or {}) do
      if t.keys["maps.minimapButton"] then veces = veces + 1 donde[#donde + 1] = p.key .. "/" .. tostring(t.name) end
    end
  end
  check(veces == 1, "el botón del minimapa sale " .. veces .. " veces: " .. table.concat(donde, ", "))
end)

---------------------------------------------------------------------------
-- 5. Relojes que duermen
---------------------------------------------------------------------------
step("Minimapa: los botones de otros addons sin reloj, salvo durante el fundido", function()
  local Co = NS_OF("Alfa_Comodidades")
  local Mm = Co.Minimapa
  local otro = rawget(_G, "LibDBIcon10_Prueba132") or CreateFrame("Button", "LibDBIcon10_Prueba132", Minimap)
  A.Set("comodidades.minimapa", true)
  A.Set("comodidades.minimapaBotones", true)
  Mm.Aplicar()
  RUN_TIMERS(2)
  check(Mm.Botones[otro], "el botón del otro addon no se esconde")
  check(not N.HayTarea("comodidades.minimapa"), "sin el ratón encima sigue corriendo el reloj del minimapa")
  check((otro:GetAlpha() or 1) <= 0.01, "el botón del otro addon no quedó escondido")
  -- El ratón entra: el fundido, y al terminar el reloj se va.
  local sobre = Minimap.IsMouseOver
  Minimap.IsMouseOver = function() return true end
  FIRE(Minimap, "OnEnter")
  check(N.HayTarea("comodidades.minimapa"), "al entrar el ratón no empezó el fundido")
  RUN_TIMERS(4)
  check((otro:GetAlpha() or 0) >= 0.99, "con el ratón encima el botón no apareció")
  check(not N.HayTarea("comodidades.minimapa"), "terminado el fundido sigue el reloj")
  -- Sale: se esconde otra vez.
  Minimap.IsMouseOver = sobre
  FIRE(Minimap, "OnLeave")
  RUN_TIMERS(4)
  check((otro:GetAlpha() or 1) <= 0.01, "al salir el ratón el botón no se escondió")
  check(not N.HayTarea("comodidades.minimapa"), "escondido, sigue el reloj")
  A.Set("comodidades.minimapaBotones", false)
  Mm.Aplicar()
end)

step("Recolección: sus relojes solo con su mapa a la vista", function()
  local Mu = rawget(_G, "AlfaMundo")
  local mapa = rawget(_G, "AlfaMundoMapa")
  if mapa and mapa:IsShown() then mapa:Hide() end
  check(not N.HayTarea("recoleccion.mapaMundo"), "con el mapa de Alfa cerrado corre «recoleccion.mapaMundo»")
  if Mu and Mu.Abrir then
    Mu.Abrir()
    RUN_TIMERS(1)
    check(N.HayTarea("recoleccion.mapaMundo"), "con el mapa de Alfa abierto no corre «recoleccion.mapaMundo»")
    if Mu.Cerrar then Mu.Cerrar() end
    RUN_TIMERS(1)
    check(not N.HayTarea("recoleccion.mapaMundo"), "al cerrar el mapa de Alfa sigue «recoleccion.mapaMundo»")
  end
  -- El minimapa a la vista: su vigía; escondido, no.
  check(N.HayTarea("recoleccion.minimapa"), "con el minimapa a la vista no corre su vigía")
  Minimap:Hide()
  check(not N.HayTarea("recoleccion.minimapa"), "con el minimapa escondido sigue «recoleccion.minimapa»")
  Minimap:Show()
  check(N.HayTarea("recoleccion.minimapa"), "al volver el minimapa no volvió su vigía")
end)

print("PRUEBA: 1.3.2 ajustes, " .. pasos .. " pasos, " .. #ERRORS .. " errores")
